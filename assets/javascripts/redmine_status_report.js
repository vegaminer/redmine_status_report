$(document).on('click', '.tabs .tab[data-tab]', (e) => {
    e.preventDefault();

    const clicked = $(e.target),
        tabsContainer = clicked.parents('.tabs[data-view-container]'),
        viewsContainer = $('#' + tabsContainer.data('viewContainer')),
        tabName = clicked.data('tab');

    if (!viewsContainer) {
        return;
    }

    //console.log('AAAA');
    //console.log(tabsContainer);
    //console.log(tabsContainer.find('.tab'));
    tabsContainer.find('.tab').removeClass('selected');

    clicked.addClass('selected');

    //console.log('BBBB');
    //console.log(viewsContainer);
    //console.log(viewsContainer.find('.tab'));

    viewsContainer.children('.tab').removeClass('selected');
    viewsContainer.children(`.tab.${tabName}`).addClass('selected');

    //viewsContainer.find('.tab').removeClass('selected');
    //viewsContainer.find(`.tab.${tabName}`).addClass('selected');
});
