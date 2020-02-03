class RedmineStatusReportHelper
  extend ActionView::Helpers::DateHelper

  def self.base_sql(issue_id)
    <<-SQL
SELECT _t.*
     , s.name as status_name
     , concat(u.firstname, ' ', u.lastname) as user_name
     , unix_timestamp(till) - unix_timestamp(since) as transition_age_secs
FROM (
    SELECT * FROM (
        SELECT
              i.created_on AS since
            , i.author_id AS user_id
            , IFNULL( ( 
                SELECT
                     jf.created_on AS till
                FROM #{Journal.table_name} jf
                    JOIN #{JournalDetail.table_name} d ON d.journal_id = jf.id
                WHERE jf.journalized_type = 'Issue'
                    AND jf.journalized_id = i.id
                    AND d.prop_key = 'status_id'
                ORDER BY d.id
                LIMIT 1 
                ), IF ( i.closed_on IS NULL, NOW(), i.closed_on ) 
            ) AS till
            , 1 AS status_id
        FROM 
            #{Issue.table_name} i
        WHERE 
            i.id = #{issue_id}    
    ) AS _first
    
    UNION ALL
    
    SELECT * FROM (
        SELECT 
              j.created_on AS since
            , j.user_id
            , IFNULL ( ( SELECT 
                    jn.created_on
                FROM 
                    #{Journal.table_name} jn
                LEFT JOIN #{JournalDetail.table_name} jnd ON jnd.journal_id = jn.id 
                WHERE jn.journalized_id = j.journalized_id AND jn.journalized_type = 'Issue' 
                    AND jnd.id > d.id AND jnd.prop_key = 'status_id' 
                ORDER BY jnd.id LIMIT 1 ), IF ( i.closed_on IS NULL, NOW(), NULL ) ) AS till
            , d.value AS status_id   
        FROM #{Journal.table_name} j
              LEFT JOIN #{JournalDetail.table_name} d on d.journal_id = j.id 
              LEFT JOIN #{Issue.table_name} i ON j.journalized_id = i.id
        WHERE j.journalized_id = #{issue_id}
            AND j.journalized_type = 'Issue'
            AND d.prop_key = 'status_id'
        ORDER by d.id
    ) AS _all
  ) AS _t
  
  JOIN #{IssueStatus.table_name} s on s.id = _t.status_id
  LEFT JOIN #{User.table_name} u on u.id = _t.user_id
    SQL
  end

  def self.load_all(issue)
    res = ActiveRecord::Base.connection.exec_query base_sql(issue.id)

    total = res.reduce(0) { |sum, row| sum + row['transition_age_secs'].to_i }

    res.each_with_index do |row, idx|
      row['percent'] = (100 * row['transition_age_secs'].to_f / total).round(2)
      row['percent_running_total'] = idx == 0 ? 0 : (res[idx - 1]['percent'] + res[idx - 1]['percent_running_total']).round(2)
    end

    # if issue.closed?
      # last_rec = res[res.length - 1]

      # last_rec['till'] = nil
      # last_rec['transition_age_secs'] = nil
      # last_rec['percent'] = 0
      # last_rec['percent_running_total'] = 0
    # end

    res
  end

  def self.load_stats(issue)
    sql = <<-SQL
      SELECT status_id, status_name, sum(transition_age_secs) as total_status_secs FROM (
        #{base_sql(issue.id)}
      ) AS _t
      GROUP BY status_id, status_name
    SQL

    res = ActiveRecord::Base.connection.exec_query sql

    total = res.reduce(0) { |sum, row| sum + row['total_status_secs'].to_i }

    res.map do |row|
      row['percent'] = (100 * row['total_status_secs'].to_f / total).round(2)
      row
    end
    
    res = res.to_a
    totalIssueTime = Hash[ 'status_id' => -1, 'status_name' => '__total__', 'total_status_secs' => total, 'percent' => 100 ]
    res = [ totalIssueTime ] + res
  end

  def self.secs_to_duration_string(secs)
    if secs.nil?
      return nil
    end

    secs = distance_of_time_in_words(0, secs, include_seconds: true)
  end
  
  def self.secs_to_hours(secs)
    if secs.nil?
      return nil
    end

    tHours = ( secs / 3600 ).floor
    tMinutes = ( ( secs - tHours * 3600 ) / 60 ).floor
    tSecs = secs - tHours * 3600 - tMinutes * 60

    res = tHours.to_s + ':' + tMinutes.to_s + ':' + tSecs.to_s  
  end
end
