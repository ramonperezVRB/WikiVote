$( function () {
	// statistics bar

	mw.pageTriage.ListStatsNav = Backbone.View.extend( {
		tagName: 'div',
		template: _.template( $( '#listStatsNavTemplate' ).html() ),

		initialize: function ( options ) {
			var that = this;

			this.eventBus = options.eventBus; // access the eventBus

			if ( mw.config.get( 'wgPageTriageStickyStatsNav' ) ) {
				this.setWaypoint(); // create scrolling waypoint

				// reset the width when the window is resized
				$( window ).resize( _.debounce( that.setWidth, 80 ) );

				// when the list view is updated, see if we need to change the
				// float state of the navbar
				this.eventBus.bind( 'articleListChange', function () {
					that.setPosition();
				} );
			}
		},

		render: function () {
			var that = this;

			// insert the template into the document.  fill with the current model.
			$( '#mwe-pt-list-stats-nav-content' ).html( this.template( this.model.toJSON() ) );

			// run setPosition since the statsNav may need to be floated immediately
			if ( mw.config.get( 'wgPageTriageStickyStatsNav' ) ) {
				this.setPosition();
			}

			// Initialize Refresh List button
			$( '#mwe-pt-refresh-button' ).button().click( function ( e ) {
				// list refreshing is handled by the ListControlNav since it controls the page list
				that.eventBus.trigger( 'refreshListRequest' );
				e.stopPropagation();
			} );

			// broadcast the stats in case any other views want to display bits of them.
			// (the control view displays a summary)
			this.eventBus.trigger( 'renderStats', this.model );

			return this;
		},

		// Create a waypoint trigger that floats the navbar when the user scrolls up
		setWaypoint: function () {
			var that = this;
			$( '#mwe-pt-list-stats-nav-anchor' ).waypoint( 'destroy' );  // remove the old, maybe inaccurate ones.
			$.waypoints.settings.scrollThrottle = 30;
			$( '#mwe-pt-list-stats-nav-anchor' ).waypoint( function ( event, direction ) {
				if ( direction === 'up' ) {
					$( '#mwe-pt-list-stats-nav' ).parent().addClass( 'stickyBottom' );
					that.setWidth();
				} else {
					$( '#mwe-pt-list-stats-nav' ).parent().removeClass( 'stickyBottom' );
				}
				event.stopPropagation();
			}, {
				offset: '100%' // bottom of page
			} );
		},

		// See if the navbar needs to be floated (for non-scrolling events)
		setPosition: function () {
			var viewportBottom = $( window ).scrollTop() + $( window ).height();
			// See if the nav anchor is visible in the current viewport
			if ( viewportBottom > $( '#mwe-pt-list-stats-nav-anchor' ).offset().top ) {
				// turn off floating nav, bring the bar back into the list.
				$( '#mwe-pt-list-stats-nav' ).parent().removeClass( 'stickyBottom' );
			} else {
				// bottom nav isn't visible.  turn on the floating navbar
				$( '#mwe-pt-list-stats-nav' ).parent().addClass( 'stickyBottom' );
			}
			// set the width in case the scrollbar status has changed
			this.setWidth();
			$.waypoints( 'refresh' );
		},

		setWidth: function () {
			// set the width of the floating bar when the window resizes, if it's floating.
			// border is 2 pixels
			$( '#mwe-pt-list-stats-nav' ).css( 'width', $( '#mw-content-text' ).width() - 2 + 'px' );
		}

	} );
} );
