<?php
/**
 * This file defines the SpecialNewPagesFeed class which handles the functionality for the
 * New Pages Feed (Special:NewPagesFeed).
 *
 * @file
 * @ingroup Extensions
 * @author Ryan Kaldari
 */
class SpecialNewPagesFeed extends SpecialPage {
	// Holds the various options for viewing the list
	protected $opts;

	/**
	 * Initialize the special page.
	 */
	public function __construct() {
		parent::__construct( 'NewPagesFeed' );
	}

	/**
	 * Define what happens when the special page is loaded by the user.
	 * @param $sub string The subpage, if any
	 */
	public function execute( $sub ) {
		global	$wgPageTriageInfiniteScrolling,
				$wgPageTriageStickyControlNav, $wgPageTriageStickyStatsNav,
				$wgPageTriageLearnMoreUrl, $wgPageTriageFeedbackUrl,
				$wgPageTriageNamespaces;

		$this->setHeaders();
		$out = $this->getOutput();
		$user = $this->getUser();

		if ( !$user->isAnon() ) {
			$now = wfTimestampNow();
			DeferredUpdates::addCallableUpdate( function() use ( $user, $now ) {
				$user->setOption( 'pagetriage-lastuse', $now );
				$user->saveSettings();
			} );
		}

		// Output the title of the page
		$out->setPageTitle( $this->msg( 'newpagesfeed' ) );

		// Make sure global vars are strings rather than booleans (for passing to mw.config)
		$wgPageTriageInfiniteScrolling = $this->booleanToString( $wgPageTriageInfiniteScrolling );
		$wgPageTriageStickyControlNav = $this->booleanToString( $wgPageTriageStickyControlNav );
		$wgPageTriageStickyStatsNav = $this->booleanToString( $wgPageTriageStickyStatsNav );

		// Allow infinite scrolling override from query string parameter
		// We don't use getBool() here since the param is optional
		$request = $this->getRequest();
		if ( $request->getText( 'infinite' ) === 'true' ) {
			$wgPageTriageInfiniteScrolling = 'true';
		} elseif ( $request->getText( 'infinite' ) === 'false' ) {
			$wgPageTriageInfiniteScrolling = 'false';
		}

		// Set the config flags in JavaScript
		$globalVars = [
			'wgPageTriageNamespaces' => $wgPageTriageNamespaces,
			'wgPageTriageInfiniteScrolling' => $wgPageTriageInfiniteScrolling,
			'wgPageTriageStickyControlNav' => $wgPageTriageStickyControlNav,
			'wgPageTriageStickyStatsNav' => $wgPageTriageStickyStatsNav,
			'wgPageTriageEnableReviewButton' => $user->isLoggedIn() && $user->isAllowed( 'patrol' ),
		];
		$out->addJsConfigVars( $globalVars );

		// Load the JS
		$out->addModules( [
			'ext.pageTriage.external',
			'ext.pageTriage.util',
			'ext.pageTriage.models',
			'ext.pageTriage.views.list'
		] );

		$warnings = '';
		$warnings .= '<div id="mwe-pt-list-warnings" style="display: none;">';
		$parsedWelcomeMessage = $this->msg(
			'pagetriage-welcome',
			$wgPageTriageLearnMoreUrl,
			$wgPageTriageFeedbackUrl
		)->parse();
		$warnings .= Html::rawElement( 'div', [ 'class' => 'plainlinks' ], $parsedWelcomeMessage );
		$warnings .= '</div>';
		$out->addHtml( $warnings );
		$out->addInlineStyle(
			'.client-nojs #mwe-pt-list-view, .client-js #mwe-pt-list-view-no-js { display: none; }'
		);

		// This will hold the HTML for the triage interface
		$triageInterface = '';

		$triageInterface .= "<div id='mwe-pt-list-control-nav-anchor'></div>";
		$triageInterface .= "<div"
			. " id='mwe-pt-list-control-nav'"
			. " class='mwe-pt-navigation-bar mwe-pt-control-gradient'>";
		$triageInterface .= "<div id='mwe-pt-list-control-nav-content'></div>";
		$triageInterface .= "</div>";

		// TODO: this should load with a spinner instead of "please wait"
		$triageInterface .= "<div id='mwe-pt-list-view'>"
			. $this->msg( 'pagetriage-please-wait' )
			. "</div>";
		$triageInterface .= "<div id='mwe-pt-list-view-no-js'>"
			. $this->msg( 'pagetriage-js-required' )
			. "</div>";
		$triageInterface .= "<div id='mwe-pt-list-errors' style='display: none;'></div>";
		$triageInterface .= "<div id='mwe-pt-list-more' style='display: none;'>";
		$triageInterface .= "<a href='#' id='mwe-pt-list-more-link'>"
			. $this->msg( 'pagetriage-more' )
			. "</a>";
		$triageInterface .= "</div>";
		$triageInterface .= "<div id='mwe-pt-list-load-more-anchor'></div>";
		$triageInterface .= "<div"
			. " id='mwe-pt-list-stats-nav'"
			. " class='mwe-pt-navigation-bar mwe-pt-control-gradient'"
			. " style='display: none;'>";
		$triageInterface .= "<div id='mwe-pt-list-stats-nav-content'></div>";
		$triageInterface .= "</div>";
		$triageInterface .= "<div id='mwe-pt-list-stats-nav-anchor'></div>";

		$dropdownArrow = $this->getLanguage()->isRtl()
			? '&#x25c2;'	// ◂ left-pointing triangle
			: '&#x25b8;';	// ▸ right-pointing triangle

		// These are the templates that backbone/underscore render on the client.
		// It would be awesome if they lived in separate files, but we need to figure out how to
		// make RL do that for us.
		// Syntax documentation can be found at http://documentcloud.github.com/underscore/#template.
		$triageInterface .= <<<HTML
			<!-- top nav template -->
			<script type="text/template" id="listControlNavTemplate">
				<span class="mwe-pt-control-label">
					<b><%= mw.msg( 'pagetriage-showing' ) %></b>
					<span id="mwe-pt-filter-status"></span>
				</span>
				<span class="mwe-pt-control-label-right" id="mwe-pt-control-stats"></span><br/>
				<span class="mwe-pt-control-label-right"><b><%= mw.msg( 'pagetriage-sort-by' ) %></b>
					<span id="mwe-pt-sort-buttons">
						<input type="radio" id="mwe-pt-sort-newest" name="sort" />
						<label for="mwe-pt-sort-newest"><%= mw.msg( 'pagetriage-newest' ) %></label>
						<input type="radio" id="mwe-pt-sort-oldest" name="sort" />
						<label for="mwe-pt-sort-oldest"><%= mw.msg( 'pagetriage-oldest' ) %></label>
					</span>
				</span>
				<span id="mwe-pt-filter-dropdown-control" class="mwe-pt-control-label">
					<b>
						<%= mw.msg( 'pagetriage-filter-list-prompt' ) %>
						<span id="mwe-pt-dropdown-arrow">$dropdownArrow</span>
						<!--<span class="mwe-pt-dropdown-open">&#x25be;</span>-->
					</b>
					<div id="mwe-pt-control-dropdown-pokey"></div>
					<div id="mwe-pt-control-dropdown" class="mwe-pt-control-gradient shadow">
						<form>
							<div class="mwe-pt-control-section">
								<span class="mwe-pt-control-label">
									<b><%= mw.msg( 'pagetriage-filter-show-heading' ) %></b>
								</span>
								<div class="mwe-pt-control-options">
									<input type="checkbox" id="mwe-pt-filter-unreviewed-edits" />
									<label for="mwe-pt-filter-unreviewed-edits">
										<%= mw.msg( 'pagetriage-filter-unreviewed-edits' ) %>
									</label> <br/>
									<input type="checkbox" id="mwe-pt-filter-reviewed-edits" />
									<label for="mwe-pt-filter-reviewed-edits">
										<%= mw.msg( 'pagetriage-filter-reviewed-edits' ) %>
									</label> <br/>
									<input type="checkbox" id="mwe-pt-filter-nominated-for-deletion" />
									<label for="mwe-pt-filter-nominated-for-deletion">
										<%= mw.msg( 'pagetriage-filter-nominated-for-deletion' ) %>
									</label> <br/>
									<input type="checkbox" id="mwe-pt-filter-redirects" />
									<label for="mwe-pt-filter-redirects">
										<%= mw.msg( 'pagetriage-filter-redirects' ) %>
									</label> <br/>
								</div>
							</div>
							<div class="mwe-pt-control-section">
								<span class="mwe-pt-control-label">
									<b><%= mw.msg( 'pagetriage-filter-namespace-heading' ) %></b>
								</span>
								<div class="mwe-pt-control-options">
									<select id="mwe-pt-filter-namespace">
										<!--<option value="">
											<%= mw.msg( 'pagetriage-filter-ns-all' ) %>
										</option>-->
										<%
											var wgFormattedNamespaces = mw.config.get( 'wgFormattedNamespaces' );
											var wgPageTriageNamespaces = mw.config.get( 'wgPageTriageNamespaces' );
											var nsOptions = '', namespaceNumber;
											for ( var key in wgFormattedNamespaces ) {
												namespaceNumber = wgPageTriageNamespaces[key];
												if ( typeof wgFormattedNamespaces[namespaceNumber] === 'undefined' ) {
													continue;
												}
												if ( wgFormattedNamespaces[namespaceNumber] === '' ) {
													nsOptions += String(
														'<option value="' + String(namespaceNumber) + '">'
														+ mw.msg( 'pagetriage-filter-article' )
														+ '</option>'
													);
												} else {
													nsOptions += String(
														'<option value="' + String(namespaceNumber) + '">'
														+ wgFormattedNamespaces[namespaceNumber]
														+ '</option>'
													);
												}
											}
											print(nsOptions);
										%>
									</select>
								</div>
							</div>
							<!-- abusefilter tags come later.
							<div class="mwe-pt-control-section">
								<span class="mwe-pt-control-label">
									<b><%= mw.msg( 'pagetriage-filter-tag-heading' ) %></b>
								</span>
								<div class="mwe-pt-control-options">
									<input type=text id="mwe-pt-filter-tag" />
								</div>
							</div>
							-->
							<div class="mwe-pt-control-section">
								<span class="mwe-pt-control-label">
									<b><%= mw.msg( 'pagetriage-filter-second-show-heading' ) %></b>
								</span>
								<div class="mwe-pt-control-options">
									<input type="radio" name="mwe-pt-filter-radio" id="mwe-pt-filter-no-categories" />
									<label for="mwe-pt-filter-no-categories">
										<%= mw.msg( 'pagetriage-filter-no-categories' ) %>
									</label> <br/>
									<input type="radio" name="mwe-pt-filter-radio" id="mwe-pt-filter-orphan" />
									<label for="mwe-pt-filter-orphan">
										<%= mw.msg( 'pagetriage-filter-orphan' ) %>
									</label> <br/>
									<input type="radio" name="mwe-pt-filter-radio" id="mwe-pt-filter-non-autoconfirmed" />
									<label for="mwe-pt-filter-non-autoconfirmed">
										<%= mw.msg( 'pagetriage-filter-non-autoconfirmed' ) %>
									</label> <br/>
									<input type="radio" name="mwe-pt-filter-radio" id="mwe-pt-filter-blocked" />
									<label for="mwe-pt-filter-blocked">
										<%= mw.msg( 'pagetriage-filter-blocked' ) %>
									</label> <br/>
									<input type="radio" name="mwe-pt-filter-radio" id="mwe-pt-filter-bot-edits" />
									<label for="mwe-pt-filter-bot-edits">
										<%= mw.msg( 'pagetriage-filter-bot-edits' ) %>
									</label> <br/>
									<input type="radio" name="mwe-pt-filter-radio" id="mwe-pt-filter-user-selected" />
									<label for="mwe-pt-filter-user-selected">
										<%= mw.msg( 'pagetriage-filter-user-heading' ) %>
									</label>
									<input type="text" id="mwe-pt-filter-user"
										placeholder="<%= mw.msg( 'pagetriage-filter-username' ) %>" /> <br/>
									<input type="radio" name="mwe-pt-filter-radio" id="mwe-pt-filter-all" />
									<label for="mwe-pt-filter-all">
										<%= mw.msg( 'pagetriage-filter-all' ) %>
									</label>
								</div>
							</div>
							<div class="mwe-pt-control-buttons">
								<div id="mwe-pt-filter-set-button" class="ui-button-green"></div>
							</div>
						</form>
					</div>
				</span>
			</script>

			<!-- bottom nav template -->
			<script type="text/template" id="listStatsNavTemplate">
				<div id="mwe-pt-refresh-button-holder">
					<button id="mwe-pt-refresh-button"><%= mw.msg( 'pagetriage-refresh-list' ) %></button>
				</div>
				<div id="mwe-pt-unreviewed-stats">
				<% if ( ptrUnreviewedCount ) { %>
					<%= mw.msg( 'pagetriage-unreviewed-article-count', ptrUnreviewedCount, ptrOldest ) %>
				<% } %>
				</div>
				<div id="mwe-pt-reviewed-stats">
				<% if ( ptrReviewedCount ) { %>
					<%= mw.msg( 'pagetriage-reviewed-article-count-past-week', ptrReviewedCount ) %>
				<% } %>
				</div>
			</script>
HTML;

		// Output the HTML for the triage interface
		$out->addHtml( $triageInterface );

	}

	/**
	 * Helper function to convert booleans to strings (for passing to mw.config)
	 * @param boolean $value The value to convert into a string
	 * @return bool|string
	 */
	private function booleanToString( $value ) {
		if ( is_string( $value ) ) {
			return $value;
		} else {
			// Convert to string
			return $value ? 'true' : 'false';
		}
	}

	protected function getGroupName() {
		return 'changes';
	}
}
