// Article represents the metadata for a single article.
// ArticleList is a collection of articles for use in the list view
//
$( function () {
	mw.pageTriage.Article = Backbone.Model.extend( {
		defaults: {
			title: 'Empty Article',
			pageid: ''
		},

		initialize: function ( options ) {
			this.bind( 'change', this.formatMetadata, this );
			this.pageId = options.pageId;

			if ( options.includeHistory ) {
				// fetch the history too?
				// don't do this when fetching via collection, since it'll generate one ajax request per article.
				// don't execute on every model change, just when loading a different page
				this.bind( 'change:pageid', this.addHistory, this );
			}
		},

		formatMetadata: function ( article ) {
			// jscs: disable requireCamelCaseOrUpperCaseIdentifiers
			var bylineMessage, user_creation_date_parsed, byline, titleUrl,
				creation_date_parsed = Date.parseExact( article.get( 'creation_date' ), 'yyyyMMddHHmmss' );

			article.set(
				'creation_date_pretty',
				creation_date_parsed.toString( mw.msg( 'pagetriage-creation-dateformat' ) )
			);

			// sometimes user info isn't set, so check that first.
			if ( article.get( 'user_creation_date' ) ) {
				user_creation_date_parsed = Date.parseExact(
					article.get( 'user_creation_date' ),
					'yyyyMMddHHmmss'
				);
				article.set(
					'user_creation_date_pretty', user_creation_date_parsed.toString( mw.msg( 'pagetriage-info-timestamp-date-format' ) ) );
			} else {
				article.set( 'user_creation_date_pretty', '' );
			}

			// TODO: What if userName doesn't exist?
			if ( article.get( 'user_name' ) ) {
				// decide which byline message to use depending on if the editor is new or not
				// but don't show new editor for ip users
				if ( article.get( 'user_id' ) > '0' && article.get( 'user_autoconfirmed' ) < '1' ) {
					bylineMessage = 'pagetriage-byline-new-editor';
				} else {
					bylineMessage = 'pagetriage-byline';
				}

				// put it all together in the byline
				byline = mw.msg(
					bylineMessage,
					this.buildLinkTag(
						article.get( 'creator_user_page_url' ),
						article.get( 'user_name' ),
						article.get( 'creator_user_page_exist' )
					),
					this.buildLinkTag(
						article.get( 'creator_user_talk_page_url' ),
						mw.msg( 'sp-contributions-talk' ),
						article.get( 'creator_user_talk_page_exist' )
					),
					mw.msg( 'pipe-separator' ),
					this.buildLinkTag(
						article.get( 'creator_contribution_page_url' ),
						mw.msg( 'contribslink' ),
						true
					)
				);

				article.set( 'author_byline', byline );
				article.set(
					'user_title_url',
					this.buildRedLink(
						article.get( 'creator_user_page_url' ),
						article.get( 'creator_user_page_exist' )
					)
				);
				article.set(
					'user_talk_title_url',
					this.buildRedLink(
						article.get( 'creator_user_talk_page_url' ),
						article.get( 'creator_user_talk_page_exist' )
					)
				);
				article.set( 'user_contribs_title', article.get( 'creator_contribution_page' ) );
			}

			// set the article status
			// delete status
			if ( article.get( 'afd_status' ) === '1' || article.get( 'blp_prod_status' ) === '1' ||
				article.get( 'csd_status' ) === '1' || article.get( 'prod_status' ) === '1' ) {
				article.set( 'page_status', mw.msg( 'pagetriage-page-status-delete' ) );
			// unreviewed status
			} else if ( article.get( 'patrol_status' ) === '0' ) {
				article.set( 'page_status', mw.msg( 'pagetriage-page-status-unreviewed' ) );
			// auto-reviewed status
			} else if ( article.get( 'patrol_status' ) === '3' ) {
				article.set( 'page_status', mw.msg( 'pagetriage-page-status-autoreviewed' ) );
			// reviewed status
			} else {
				if ( article.get( 'ptrp_last_reviewed_by' ) !== 0 && article.get( 'reviewer' ) ) {
					article.set(
						'page_status',
						mw.msg(
							'pagetriage-page-status-reviewed',
							Date.parseExact(
								article.get( 'ptrp_reviewed_updated' ),
								'yyyyMMddHHmmss'
							).toString(
								mw.msg( 'pagetriage-info-timestamp-date-format' )
							),
							this.buildLinkTag(
								article.get( 'reviewer_user_page_url' ),
								article.get( 'reviewer' ),
								article.get( 'reviewer_user_page_exist' )
							),
							this.buildLinkTag(
								article.get( 'reviewer_user_talk_page_url' ),
								mw.msg( 'sp-contributions-talk' ),
								article.get( 'reviewer_user_talk_page_exist' )
							),
							mw.msg( 'pipe-separator' ),
							this.buildLinkTag(
								article.get( 'reviewer_contribution_page_url' ),
								mw.msg( 'contribslink' ),
								true
							)
						)
					);
				} else {
					article.set( 'page_status', mw.msg( 'pagetriage-page-status-reviewed-anonymous' ) );
				}
			}

			article.set( 'title_url_format', mw.util.wikiUrlencode( article.get( 'title' ) ) );

			titleUrl = mw.util.getUrl( article.get( 'title' ) );
			if ( Number( article.get( 'is_redirect' ) ) === 1 ) {
				titleUrl = this.buildLink( titleUrl, 'redirect=no' );
			}
			article.set( 'title_url', titleUrl );
			// jscs: enable requireCamelCaseOrUpperCaseIdentifiers
		},

		tagWarningNotice: function () {
			var now, begin, diff,
				dateStr = this.get( 'creation_date_utc' );
			if ( !dateStr ) {
				return '';
			}

			now = new Date();
			now = new Date(
				now.getUTCFullYear(),
				now.getUTCMonth(),
				now.getUTCDate(),
				now.getUTCHours(),
				now.getUTCMinutes(),
				now.getUTCSeconds()
			);

			begin = Date.parseExact( dateStr, 'yyyyMMddHHmmss' );
			diff = Math.round( ( now.getTime() - begin.getTime() ) / ( 1000 * 60 ) );

			// only generate a warning if the page is less than 30 minutes old
			if ( diff < 30 ) {
				if ( diff < 1 ) {
					diff = 1;
				}
				return mw.msg( 'pagetriage-tag-warning-notice', diff );
			} else {
				return '';
			}
		},

		buildLinkTag: function ( url, text, exists ) {
			var style = '';
			if ( !exists ) {
				url = this.buildRedLink( url, exists );
				style = 'new';
			}
			return mw.html.element(
				'a',
				{
					href: url,
					class: style
				},
				text
			);
		},

		buildRedLink: function ( url, exists ) {
			if ( !exists ) {
				url = this.buildLink( url, 'action=edit&redlink=1' );
			}
			return url;
		},

		buildLink: function ( url, param ) {
			var mark;
			if ( param ) {
				mark = ( url.indexOf( '?' ) === -1 ) ? '?' : '&';
				url += mark + param;
			}
			return url;
		},

		// url and parse are used here for retrieving a single article in the curation toolbar.
		// articles are retrived for list view using the methods in the Articles collection.
		url: function () {
			var d = new Date(),
				params = $.param( {
					action: 'pagetriagelist',
					format: 'json',
					timestamp: d.getTime()
				} );
			// jscs: disable requireCamelCaseOrUpperCaseIdentifiers
			return mw.util.wikiScript( 'api' ) + '?' + params + '&' + $.param( { page_id: this.pageId } );
			// jscs: enable requireCamelCaseOrUpperCaseIdentifiers
		},

		parse: function ( response ) {
			if ( response.pagetriagelist !== undefined && response.pagetriagelist.pages !== undefined ) {
				// data came directly from the api
				// extract the useful bits of json.
				return response.pagetriagelist.pages[ 0 ];
			} else {
				// already parsed by the collection's parse function.
				return response;
			}
		},

		addHistory: function () {
			this.revisions = new mw.pageTriage.RevisionList( { eventBus: this.eventBus, pageId: this.pageId } );
			this.revisions.fetch();
		}
	} );

	mw.pageTriage.ArticleList = Backbone.Collection.extend( {
		moreToLoad: true,
		model: mw.pageTriage.Article,
		optionsToken: '',

		apiParams: {
			limit: 20,
			dir: 'newestfirst',
			namespace: 0,
			showreviewed: 1,
			showunreviewed: 1,
			showdeleted: 1
			/*
			showredirs: 0
			showbots: 0,
			no_category: 0,
			no_inbound_links: 0,
			non_autoconfirmed_users: 0,
			blocked_users: 0,
			username: null
			*/
		},

		initialize: function ( options ) {
			this.eventBus = options.eventBus;
			this.eventBus.bind( 'filterSet', this.setParams );

			// pull any saved filter settings from the user's option
			if ( !mw.user.isAnon() && mw.user.options.get( 'userjs-NewPagesFeedFilterOptions' ) ) {
				this.setParams( JSON.parse( mw.user.options.get( 'userjs-NewPagesFeedFilterOptions' ) ) );
			}
		},

		url: function () {
			var d = new Date(),
				params = $.param( {
					action: 'pagetriagelist',
					format: 'json',
					timestamp: d.getTime()
				} );
			return mw.util.wikiScript( 'api' ) + '?' + params + '&' + $.param( this.apiParams );
		},

		parse: function ( response ) {
			// See if the fetch returned an extra page or not. This lets us know if there are more
			// pages to load in a subsequent fetch.
			if ( response.pagetriagelist.pages && response.pagetriagelist.pages.length > this.apiParams.limit ) {
				// Remove the extra page from the list
				response.pagetriagelist.pages.pop();
				this.moreToLoad = true;
			} else {
				// We have no more pages to load.
				this.moreToLoad = false;
			}
			// extract the useful bits of json.
			return response.pagetriagelist.pages;
		},

		setParams: function ( apiParams ) {
			this.apiParams = apiParams;
		},

		setParam: function ( paramName, paramValue ) {
			this.apiParams[ paramName ] = paramValue;
		},

		encodeFilterParams: function () {
			var str,
				encodedString = '',
				paramArray = [];

			$.each( this.apiParams, function ( key, val ) {
				str = '"' + key + '":';
				if ( typeof val === 'string' ) {
					val = '"' + val.replace( /[\"]/g, '\\"' ) + '"';
				}
				str += val;
				paramArray.push( str );
			} );
			encodedString = '{ ' + paramArray.join( ', ' ) + ' }';
			return encodedString;
		},

		// Save the filter parameters to a user's option
		saveFilterParams: function () {
			var tokenRequest,
				that = this;
			if ( !mw.user.isAnon() ) {
				if ( this.optionsToken ) {
					this.apiSetFilterParams();
				} else {
					tokenRequest = {
						action: 'tokens',
						type: 'options',
						format: 'json'
					};
					$.ajax( {
						type: 'get',
						url: mw.util.wikiScript( 'api' ),
						data: tokenRequest,
						dataType: 'json',
						success: function ( data ) {
							try {
								that.optionsToken = data.tokens.optionstoken;
							} catch ( e ) {
								throw new Error( 'Could not get token (requires MediaWiki 1.20).' );
							}
							that.apiSetFilterParams();
						}
					} );
				}
			}
		},

		apiSetFilterParams: function () {
			var prefRequest = {
				action: 'options',
				change: 'userjs-NewPagesFeedFilterOptions=' + this.encodeFilterParams(),
				token: this.optionsToken,
				format: 'json'
			};
			$.ajax( {
				type: 'post',
				url: mw.util.wikiScript( 'api' ),
				data: prefRequest,
				dataType: 'json'
			} );
		},

		getParam: function ( key ) {
			return this.apiParams[ key ];
		}

	} );

} );
