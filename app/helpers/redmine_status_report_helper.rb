class RedmineStatusReportHelper
  extend ActionView::Helpers::DateHelper

  def self.base_sql(issue)
    <<-SQL
SELECT _t.*
    , rec_count recId
    , s.name AS status_name
    , UNIX_TIMESTAMP( till ) - UNIX_TIMESTAMP( since ) AS transition_age_secs
    , get_mgt_user_type( _t.user_id, _t.project_id ) user_type
    , get_mgt_user_type( _t.next_user_id, _t.project_id ) next_user_type
    , CONCAT( u.firstname, ' ', u.lastname ) AS user_name
FROM (
    SELECT * FROM ( 
        SELECT
              i.created_on AS since
            , i.author_id AS user_id
            , i.project_id
            , IFNULL( jf.created_on, IF ( i.closed_on IS NULL, NOW(), i.closed_on ) ) till
            , 1 AS status_id
            , ( @recId := 0 ) rec_count
            , IFNULL( jf.user_id, i.author_id ) AS next_user_id
        FROM 
            issues i 
        LEFT JOIN #{Journal.table_name} jf ON jf.journalized_id = i.id AND jf.journalized_type = 'Issue'
        LEFT JOIN #{JournalDetail.table_name} d ON d.journal_id = jf.id AND d.prop_key = 'status_id'
        WHERE                
            i.id = #{issue.id}
        ORDER BY IFNULL( d.id, 999999999 )
        LIMIT 1              
    ) AS _first

    UNION ALL

    SELECT * FROM (
        SELECT 
              j.created_on AS since
            , j.user_id
            , i.project_id            
            , IFNULL( jn.created_on, IF( i.closed_on IS NULL, NOW(), NULL ) ) AS till
            , d.value AS status_id  
            , ( @recId := @recId + 1 ) rec_count
            , IFNULL( jn.user_id, IF( i.closed_on IS NULL, IFNULL( j.user_id, i.author_id ), NULL ) ) AS next_user_id        
        FROM 
            #{Journal.table_name} j
        LEFT JOIN 
            #{JournalDetail.table_name} d ON d.journal_id = j.id 
        LEFT JOIN 
            #{JournalDetail.table_name} jnd ON jnd.id = ( 
                SELECT jrd.id 
                FROM #{JournalDetail.table_name} jrd 
                LEFT JOIN 
                    #{Journal.table_name} jr ON jr.id = jrd.journal_id
                WHERE jrd.id > d.id 
                    AND jrd.prop_key = 'status_id' 
                    AND jr.journalized_id = j.journalized_id
                ORDER BY jrd.id LIMIT 1 
        )
        LEFT JOIN 
            #{Journal.table_name} jn ON jn.id = jnd.journal_id AND jn.journalized_type = 'Issue'

        LEFT JOIN 
            issues i ON i.id = j.journalized_id      

        WHERE 
            j.journalized_id = #{issue.id} 
            AND j.journalized_type = 'Issue'
            AND d.prop_key = 'status_id'
        ORDER BY d.id
    ) AS _all
  ) AS _t
  
  JOIN #{IssueStatus.table_name} s ON s.id = _t.status_id
  LEFT JOIN #{User.table_name} u ON u.id = _t.user_id
    SQL
  end

  def self.load_all(issue)
    res = ActiveRecord::Base.connection.exec_query base_sql(issue)

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
      SELECT status_id, status_name, sum(transition_age_secs) AS total_status_secs 
      FROM (
        #{base_sql(issue)}
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
