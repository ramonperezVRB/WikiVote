<?php

class PageTriageHooks {

	/**
	 * Mark a page as unreviewed after moving the page from non-main(article) namespace to
	 * main(article) namespace
	 *
	 * @see http://www.mediawiki.org/wiki/Manual:Hooks/SpecialMovepageAfterMove
	 * @param $movePage MovePageForm object
	 * @param $oldTitle Title old title object
	 * @param $newTitle Title new title object
	 * @return bool
	 */
	public static function onSpecialMovepageAfterMove( $movePage, &$oldTitle, &$newTitle ) {
		$pageId = $newTitle->getArticleID();

		// Delete cache for record if it's in pagetriage queue
		$articleMetadata = new ArticleMetadata( [ $pageId ] );
		$articleMetadata->flushMetadataFromCache();

		// Delete user status cache
		self::flushUserStatusCache( $oldTitle );
		self::flushUserStatusCache( $newTitle );

		$oldNamespace = $oldTitle->getNamespace();
		$newNamespace = $newTitle->getNamespace();
		// Do nothing further on if
		// 1. the page move is within the same namespace or
		// 2. the new page is not in article (main) namespace
		if ( $oldNamespace === $newNamespace || $newNamespace !== NS_MAIN ) {
			return true;
		}

		// New record to pagetriage queue, compile metadata
		if ( self::addToPageTriageQueue( $pageId, $newTitle, $movePage->getUser() ) ) {
			$acp = ArticleCompileProcessor::newFromPageId( [ $pageId ] );
			if ( $acp ) {
				// safe to use slave db for data compilation for the
				// following components, BasicData is accessing pagetriage_page,
				// which is not safe to use slave db
				$config = [
						'LinkCount' => DB_SLAVE,
						'CategoryCount' => DB_SLAVE,
						'Snippet' => DB_SLAVE,
						'UserData' => DB_SLAVE,
						'DeletionTag' => DB_SLAVE
				];
				$acp->configComponentDb( $config );
				$acp->compileMetadata();
			}
		}

		return true;
	}

	/**
	 * Check if a page is created from a redirect page, then insert into it PageTriage Queue
	 * Note: Page will be automatically marked as triaged for users with autopatrol right
	 *
	 * @see http://www.mediawiki.org/wiki/Manual:Hooks/NewRevisionFromEditComplete
	 * @param $page WikiPage the WikiPage edited
	 * @param $rev Revision|null the new revision
	 * @param $baseID int the revision ID this was based on, if any
	 * @param $user User the editing user
	 * @return bool
	 */
	public static function onNewRevisionFromEditComplete( $page, $rev, $baseID, $user ) {
		global $wgPageTriageNamespaces;

		if ( !in_array( $page->getTitle()->getNamespace(), $wgPageTriageNamespaces ) ) {
			return true;
		}

		if ( $rev && $rev->getParentId() ) {
			// Make sure $prev->getContent() is done post-send if possible
			DeferredUpdates::addCallableUpdate( function() use ( $rev, $page, $user ) {
				$prev = $rev->getPrevious();
				if ( $prev && !$page->isRedirect() && $prev->getContent()->isRedirect() ) {
					PageTriageHooks::addToPageTriageQueue(
						$page->getId(), $page->getTitle(), $user );
				}
			} );
		}

		return true;
	}

	/**
	 * When a new article is created, insert it into the PageTriage Queue
	 *
	 * @see http://www.mediawiki.org/wiki/Manual:Hooks/ArticleInsertComplete
	 * @param $article WikiPage created
	 * @param $user User creating the article
	 * @param $content Content New content
	 * @param $summary string Edit summary/comment
	 * @param $isMinor bool Whether or not the edit was marked as minor
	 * @param $isWatch bool (No longer used)
	 * @param $section bool (No longer used)
	 * @param $flags: Flags passed to Article::doEdit()
	 * @param $revision Revision New Revision of the article
	 * @return bool
	 */
	public static function onPageContentInsertComplete(
		$article, $user, $content, $summary, $isMinor, $isWatch, $section, $flags, $revision
	) {
		global $wgPageTriageNamespaces;
		if ( !in_array( $article->getTitle()->getNamespace(), $wgPageTriageNamespaces ) ) {
			return true;
		}

		self::addToPageTriageQueue( $article->getId(), $article->getTitle(), $user );

		return true;
	}

	/**
	 * Flush user status cache on a successful save.
	 *
	 * @see http://www.mediawiki.org/wiki/Manual:Hooks/PageContentSaveComplete
	 * @param $article WikiPage
	 * @param $user
	 * @param $content Content
	 * @param $summary
	 * @param $minoredit
	 * @param $watchthis
	 * @param $sectionanchor
	 * @param $flags
	 * @param $revision
	 * @param $status
	 * @param $baseRevId
	 * @return bool
	 */
	public static function onPageContentSaveComplete(
		$article, $user, $content, $summary, $minoredit, $watchthis, $sectionanchor, $flags, $revision,
		$status, $baseRevId
	) {
		self::flushUserStatusCache( $article->getTitle() );
		return true;
	}

	/**
	 * Update metadata when link information is updated. This is also run after every page save.
	 * @param LinksUpdate $linksUpdate
	 * @return bool
	 */

	public static function onLinksUpdateComplete( LinksUpdate $linksUpdate ) {
		global $wgPageTriageNamespaces;
		if ( !in_array( $linksUpdate->getTitle()->getNamespace(), $wgPageTriageNamespaces ) ) {
			return true;
		}

		DeferredUpdates::addCallableUpdate( function () use ( $linksUpdate ) {
			// false will enforce a validation against pagetriage_page table
			$acp = ArticleCompileProcessor::newFromPageId(
				[ $linksUpdate->getTitle()->getArticleId() ], false, DB_MASTER );

			if ( $acp ) {
				$acp->registerLinksUpdate( $linksUpdate );
				$acp->compileMetadata();
			}
		} );
		return true;
	}

	/**
	 * Remove the metadata we added when the article is deleted.
	 *
	 * 'ArticleDeleteComplete': after an article is deleted
	 * @param $article WikiPage the WikiPage that was deleted
	 * @param $user User the user that deleted the article
	 * @param $reason string the reason the article was deleted
	 * @param $id int id of the article that was deleted
	 */
	public static function onArticleDeleteComplete( $article, $user, $reason, $id ) {
		global $wgPageTriageNamespaces;

		self::flushUserStatusCache( $article->getTitle() );

		if ( !in_array( $article->getTitle()->getNamespace(), $wgPageTriageNamespaces ) ) {
			return true;
		}

		// delete everything
		$pageTriage = new PageTriage( $id );
		$pageTriage->deleteFromPageTriage();
		return true;
	}

	/**
	 * Add page to page triage queue, check for autopatrol right if reviewed is not set
	 *
	 * This method should only be called from this class and its closures
	 *
	 * @param $pageId int
	 * @param $title Title
	 * @param $user User|null
	 * @param $reviewed numeric string See PageTriage::getValidReviewedStatus()
	 * @return bool
	 */
	public static function addToPageTriageQueue( $pageId, $title, $user = null, $reviewed = null ) {
		global $wgUseRCPatrol, $wgUseNPPatrol;

		$pageTriage = new PageTriage( $pageId );

		// action taken by system
		if ( is_null( $user ) ) {
			if ( is_null( $reviewed ) ) {
				$reviewed = '0';
			}
			return $pageTriage->addToPageTriageQueue( $reviewed );
		// action taken by a user
		} else {
			// set reviewed if it's not set yet
			if ( is_null( $reviewed ) ) {
				// check if this user has autopatrol right
				if ( ( $wgUseRCPatrol || $wgUseNPPatrol ) &&
					!count( $title->getUserPermissionsErrors( 'autopatrol', $user ) ) ) {
					$reviewed = 3;
				// if the user has no autopatrol right and doesn't really take any action,
				// this would be set to unreviewed by system.
				} else {
					return $pageTriage->addToPageTriageQueue( '0' );
				}
			}
			return $pageTriage->addToPageTriageQueue( $reviewed, $user );
		}
	}

	/**
	 * Add last time user visited the triage page to preferences.
	 * @param $user User object
	 * @param &$preferences array Preferences object
	 * @return bool
	 */
	public static function onGetPreferences( $user, &$preferences ) {
		$preferences['pagetriage-lastuse'] = [
			'type' => 'api',
		];

		return true;
	}

	/**
	 * Flush user page/user talk page exsitance status, this function should
	 * be called when a page gets created/deleted/moved/restored
	 * @param $title
	 */
	private static function flushUserStatusCache( $title ) {
		global $wgMemc;

		if ( in_array( $title->getNamespace(), [ NS_USER, NS_USER_TALK ] ) ) {
			$wgMemc->delete( PageTriageUtil::userStatusKey( $title->getText() ) );
		}
	}

	/**
	 * Determines whether to set noindex for the article specified
	 *
	 * Returns true if all of the following are true:
	 *   1. The page includes a template that triggers noindexing
	 *   2. The page was at some point in the triage queue
	 *   3. The page is younger than the maximum age for "new pages"
	 * or all of the following are true:
	 *   1. $wgPageTriageNoIndexUnreviewedNewArticles is true
	 *   2. The page is in the triage queue and has not been triaged
	 *   3. The page is younger than the maximum age for "new pages"
	 * Note that we always check the age of the page last since that is
	 * potentially the most expensive check (if the data isn't cached).
	 *
	 * @param $article Article
	 * @return bool
	 */
	private static function shouldShowNoIndex( $article ) {
		global $wgPageTriageNoIndexUnreviewedNewArticles, $wgPageTriageNoIndexTemplates;

		// See if article includes any templates that should trigger noindexing
		// TODO: This system is a bit hacky and unintuitive. At some point we
		// may want to switch to a system based on the __NOINDEX__ magic word.
		if ( $wgPageTriageNoIndexTemplates && $article->mParserOutput instanceof ParserOutput ) {
			// Properly format the template names to match what getTemplates() returns
			$noIndexTemplates = array_map(
				[ 'PageTriageHooks', 'formatTemplateName' ],
				$wgPageTriageNoIndexTemplates
			);

			// getTemplates returns all transclusions, not just NS_TEMPLATE
			$allTransclusions = $article->mParserOutput->getTemplates();

			$templates = isset( $allTransclusions[NS_TEMPLATE] ) ?
				$allTransclusions[NS_TEMPLATE] :
				[];

			foreach ( $noIndexTemplates as $noIndexTemplate ) {
				if ( isset( $templates[ $noIndexTemplate ] ) ) {
					// The noindex template feature is restricted to new articles
					// to minimize the potential for abuse.
					if ( self::isArticleNew( $article ) ) {
						return true;
					} else {
						// Short circuit since we know it will fail the next set
						// of tests as well.
						return false;
					}
				}
			}
		}

		if ( $wgPageTriageNoIndexUnreviewedNewArticles &&
			PageTriageUtil::doesPageNeedTriage( $article ) &&
			self::isArticleNew( $article )
		) {
			return true;
		}

		return false;
	}

	/**
	 * Checks to see if an article is new, i.e. less than $wgRCMaxAge
	 * @param Article $article Article to check
	 * @return bool
	 */
	private static function isArticleNew( $article ) {
		global $wgRCMaxAge;

		$pageId = $article->getId();

		// Get timestamp for article creation (typically from cache)
		$metaDataObject = new ArticleMetadata( [ $pageId ] );
		$metaData = $metaDataObject->getMetadata();
		if ( $metaData && isset( $metaData[ $pageId ][ 'creation_date' ] ) ) {
			$pageCreationDateTime = $metaData[ $pageId ][ 'creation_date' ];

			// Get the age of the article in days
			$timestamp = new MWTimestamp( $pageCreationDateTime );
			$dateInterval = $timestamp->diff( new MWTimestamp() );
			$articleDaysOld = $dateInterval->format( '%a' );

			// If it's younger than the maximum age, return true.
			// We use $wgRCMaxAge here since this determines which articles are
			// considered "new", i.e. shown at Special:NewPages, and which articles
			// are eligible to be patrolled.
			if ( $articleDaysOld < ( $wgRCMaxAge / 86400 ) ) {
				return true;
			}
		}

		return false;
	}

	/**
	 * Formats a template name to match the format returned by getTemplates()
	 * @param $template string
	 * @return string
	 */
	private static function formatTemplateName( $template ) {
		$template = ucfirst( trim( $template ) );
		$template = str_replace( ' ', '_', $template );
		return $template;
	}

	/**
	 * Handler for hook ArticleViewFooter, this will determine whether to load
	 * curation toolbar or 'mark as reviewed'/'reviewed' text
	 *
	 * @param &$article Article object to show link for.
	 * @param $patrolFooterShown bool whether the patrol footer is shown
	 * @return bool
	 */
	public static function onArticleViewFooter( $article, $patrolFooterShown ) {
		global $wgPageTriageMarkPatrolledLinkExpiry,
			$wgPageTriageEnableCurationToolbar, $wgPageTriageNamespaces;

		$context = $article->getContext();
		$user = $context->getUser();
		$outputPage = $context->getOutput();
		$request = $context->getRequest();

		// Overwrite the noindex rule defined in Article::view(), this also affects main namespace
		if ( self::shouldShowNoIndex( $article ) ) {
			$outputPage->setRobotPolicy( 'noindex,nofollow' );
		}

		// Only logged in users can review
		if ( !$user->isLoggedIn() ) {
			return true;
		}

		// Don't show anything for user with no patrol right
		if ( !$article->getTitle()->quickUserCan( 'patrol' ) ) {
			return true;
		}

		// Only show in defined namespaces
		if ( !in_array( $article->getTitle()->getNamespace(), $wgPageTriageNamespaces ) ) {
			return true;
		}

		// Don't do anything if it's coming from Special:NewPages
		if ( $request->getVal( 'patrolpage' ) ) {
			return true;
		}

		// If the user hasn't visited Special:NewPagesFeed lately, don't do anything
		$lastUseExpired = false;
		$lastUse = $user->getOption( 'pagetriage-lastuse' );
		if ( $lastUse ) {
			$lastUse = wfTimestamp( TS_UNIX, $lastUse );
			$now = wfTimestamp( TS_UNIX, wfTimestampNow() );
			$periodSince = $now - $lastUse;
		}
		if ( !$lastUse || $periodSince > $wgPageTriageMarkPatrolledLinkExpiry ) {
			$lastUseExpired = true;
		}

		// See if the page is in the PageTriage page queue
		// If it isn't, $needsReview will be null
		// Also, users without the autopatrol right can't review their own pages
		$needsReview = PageTriageUtil::doesPageNeedTriage( $article );
		if ( !is_null( $needsReview )
			&& !( $user->getId() == $article->getOldestRevision()->getUser()
				&& !$user->isAllowed( 'autopatrol' )
			)
		) {
			if ( $wgPageTriageEnableCurationToolbar || $request->getVal( 'curationtoolbar' ) === 'true' ) {
				// Load the JavaScript for the curation toolbar
				$outputPage->addModules( 'ext.pageTriage.toolbarStartup' );
				// Set the config flags in JavaScript
				$globalVars = [
					'wgPageTriagelastUseExpired' => $lastUseExpired,
					'wgPageTriagePagePrefixedText' => $article->getTitle()->getPrefixedText()
				];
				$outputPage->addJsConfigVars( $globalVars );
			} else {
				if ( $needsReview ) {
					// show 'Mark as reviewed' link
					$msg = wfMessage( 'pagetriage-markpatrolled' )->text();
					$msg = Html::element(
						'a',
						[ 'href' => '#', 'class' => 'mw-pagetriage-markpatrolled-link' ],
						$msg
					);
				} else {
					// show 'Reviewed' text
					$msg = wfMessage( 'pagetriage-reviewed' )->escaped();
				}
				$outputPage->addModules( [ 'ext.pageTriage.article' ] );
				$html = Html::rawElement( 'div', [ 'class' => 'mw-pagetriage-markpatrolled' ], $msg );
				$outputPage->addHTML( $html );
			}
		}

		return true;
	}

	/**
	 * Sync records from patrol queue to triage queue
	 *
	 * 'MarkPatrolledComplete': after an edit is marked patrolled
	 * $rcid: ID of the revision marked as patrolled
	 * $user: user (object) who marked the edit patrolled
	 * $wcOnlySysopsCanPatrol: config setting indicating whether the user
	 * must be a sysop to patrol the edit
	 * @param $rcid int
	 * @param $user User
	 * @param $wcOnlySysopsCanPatrol
	 * @return bool
	 */
	public static function onMarkPatrolledComplete( $rcid, &$user, $wcOnlySysopsCanPatrol ) {
		$rc = RecentChange::newFromId( $rcid );

		if ( $rc ) {
			global $wgPageTriageNamespaces;
			if ( !in_array( $rc->getTitle()->getNamespace(), $wgPageTriageNamespaces ) ) {
				return true;
			}

			$pt = new PageTriage( $rc->getAttribute( 'rc_cur_id' ) );
			if ( $pt->addToPageTriageQueue( '2', $user, true /* fromRc */ ) ) {
				// Compile metadata for new page triage record
				$acp = ArticleCompileProcessor::newFromPageId( [ $rc->getAttribute( 'rc_cur_id' ) ] );
				if ( $acp ) {
					// page just gets added to pagetriage queue and hence not safe to use slave db
					// for BasicData since it's accessing pagetriage_page table
					$config = [
						'LinkCount' => DB_SLAVE,
						'CategoryCount' => DB_SLAVE,
						'Snippet' => DB_SLAVE,
						'UserData' => DB_SLAVE,
						'DeletionTag' => DB_SLAVE
					];
					$acp->configComponentDb( $config );
					$acp->compileMetadata();
				}
			}
			$article = Article::newFromID( $rc->getAttribute( 'rc_cur_id' ) );
			if ( $article ) {
				PageTriageUtil::createNotificationEvent( $article, $user, 'pagetriage-mark-as-reviewed' );
			}
		}

		return true;
	}

	/**
	 * Update Article metadata when a user gets blocked
	 *
	 * 'BlockIpComplete': after an IP address or user is blocked
	 * @param $block Block the Block object that was saved
	 * @param $performer User the user who did the block (not the one being blocked)
	 * @return bool
	 */
	public static function onBlockIpComplete( $block, $performer ) {
		PageTriageUtil::updateMetadataOnBlockChange( $block );
		return true;
	}

	/**
	 * Send php config vars to js via ResourceLoader
	 *
	 * @param &$vars: variables to be added to the output of the startup module
	 * @return bool
	 */
	public static function onResourceLoaderGetConfigVars( &$vars ) {
		global $wgPageTriageCurationModules, $wgPageTriageNamespaces,
			$wgTalkPageNoteTemplate;

		// check if WikiLove is enabled
		if ( ExtensionRegistry::getInstance()->isLoaded( 'WikiLove' ) ) {
			$wgPageTriageCurationModules['wikiLove'] = [
				// depends on WikiLove extension
				'helplink' => '//en.wikipedia.org/wiki/Wikipedia:Page_Curation/Help#WikiLove',
				'namespace' => [ NS_MAIN, NS_USER ],
			];
		}

		$vars['wgPageTriageCurationModules'] = $wgPageTriageCurationModules;
		$vars['wgPageTriageNamespaces'] = $wgPageTriageNamespaces;
		$vars['wgTalkPageNoteTemplate'] = $wgTalkPageNoteTemplate;
		return true;
	}

	/**
	 * Register modules that depend on other state
	 *
	 * @param ResourceLoader &$resourceLoader
	 * @return bool true
	 */
	public static function onResourceLoaderRegisterModules( &$resourceLoader ) {
		global $wgPageTriageDeletionTagsOptionsContentLanguageMessages;

		$template = [
			'localBasePath' => __DIR__. '/modules',
			'remoteExtPath' => 'PageTriage/modules'
		];

		$messagesModule = [
			'class' => 'PageTriageMessagesModule',
			'contentLanguageMessages' => array_merge(
				[
					'pagetriage-mark-mark-talk-page-notify-topic-title',
					'pagetriage-mark-unmark-talk-page-notify-topic-title',
					'pagetriage-tags-talk-page-notify-topic-title',
				],
				$wgPageTriageDeletionTagsOptionsContentLanguageMessages
			),
		];

		$resourceLoader->register( 'ext.pageTriage.messages', $messagesModule );

		$toolBaseClass = [
			'ext.pageTriage.views.toolbar/ext.pageTriage.toolView.js', // abstract class first
		];

		// Individual tools on toolbar
		$tools = [
			'ext.pageTriage.views.toolbar/ext.pageTriage.articleInfo.js', // article metadata
			'ext.pageTriage.views.toolbar/ext.pageTriage.minimize.js', // minimize
			'ext.pageTriage.views.toolbar/ext.pageTriage.tags.js', // tagging
			'ext.pageTriage.views.toolbar/ext.pageTriage.mark.js', // mark as reviewed
			'ext.pageTriage.views.toolbar/ext.pageTriage.next.js', // next article
			'ext.pageTriage.views.toolbar/ext.pageTriage.delete.js', // mark for deletion
		];

		$afterTools = [
			'ext.pageTriage.views.toolbar/ext.pageTriage.toolbarView.js', // overall toolbar view last
			'external/jquery.effects.core.js',
			'external/jquery.effects.squish.js',
		];

		$viewsToolbarModule = $template + [
			'dependencies' => [
				'mediawiki.jqueryMsg',
				'mediawiki.messagePoster',
				'mediawiki.Title',
				'ext.pageTriage.models',
				'ext.pageTriage.util',
				'jquery.badge',
				'jquery.ui.button',
				'jquery.ui.draggable',
				'jquery.spinner',
				'jquery.client',
				'ext.pageTriage.externalTagsOptions',
				'ext.pageTriage.externalDeletionTagsOptions',
				'ext.pageTriage.messages',
			],
			'styles' => [
				'ext.pageTriage.css', // stuff that's shared across all views
				'ext.pageTriage.views.toolbar/ext.pageTriage.toolbarView.css',
				'ext.pageTriage.views.toolbar/ext.pageTriage.toolView.css',
				'ext.pageTriage.views.toolbar/ext.pageTriage.articleInfo.css',
				'ext.pageTriage.views.toolbar/ext.pageTriage.mark.css',
				'ext.pageTriage.views.toolbar/ext.pageTriage.tags.css',
				'ext.pageTriage.views.toolbar/ext.pageTriage.delete.css'
			],
			'messages' => [
				'pagetriage-creation-dateformat',
				'pagetriage-user-creation-dateformat',
				'pagetriage-mark-as-reviewed',
				'pagetriage-mark-as-unreviewed',
				'pagetriage-info-title',
				'pagetriage-byline',
				'pagetriage-byline-new-editor',
				'pagetriage-articleinfo-byline',
				'pagetriage-articleinfo-byline-new-editor',
				'pipe-separator',
				'pagetriage-edits',
				'pagetriage-editcount',
				'pagetriage-author-bot',
				'pagetriage-no-author',
				'pagetriage-info-problem-header',
				'pagetriage-info-history-header',
				'pagetriage-info-history-show-full',
				'pagetriage-info-help',
				'pagetriage-info-no-problems',
				'pagetriage-info-problem-non-autoconfirmed',
				'pagetriage-info-problem-non-autoconfirmed-desc',
				'pagetriage-info-problem-blocked',
				'pagetriage-info-problem-blocked-desc',
				'pagetriage-info-problem-no-categories',
				'pagetriage-info-problem-no-categories-desc',
				'pagetriage-info-problem-orphan',
				'pagetriage-info-problem-orphan-desc',
				'pagetriage-info-problem-no-references',
				'pagetriage-info-problem-no-references-desc',
				'pagetriage-info-timestamp-date-format',
				'pagetriage-info-timestamp-time-format',
				'pagetriage-info-tooltip',
				'pagetriage-toolbar-collapsed',
				'pagetriage-toolbar-linktext',
				'pagetriage-toolbar-learn-more',
				'pagetriage-mark-as-reviewed-helptext',
				'pagetriage-mark-as-unreviewed-helptext',
				'pagetriage-mark-as-reviewed-error',
				'pagetriage-mark-as-unreviewed-error',
				'pagetriage-markpatrolled',
				'pagetriage-markunpatrolled',
				'pagetriage-note-reviewed',
				'pagetriage-note-not-reviewed',
				'pagetriage-note-deletion',
				'pagetriage-next-tooltip',
				'sp-contributions-talk',
				'contribslink',
				'comma-separator',
				'unknown-error',
				'pagetriage-add-a-note-creator',
				'pagetriage-add-a-note-reviewer',
				'pagetriage-personal-default-note',
				'pagetriage-special-contributions',
				'pagetriage-tagging-error',
				'pagetriage-del-log-page-missing-error',
				'pagetriage-del-log-page-adding-error',
				'pagetriage-del-talk-page-notify-error',
				'pagetriage-del-discussion-page-adding-error',
				'pagetriage-page-status-reviewed',
				'pagetriage-page-status-reviewed-anonymous',
				'pagetriage-page-status-unreviewed',
				'pagetriage-page-status-autoreviewed',
				'pagetriage-page-status-delete',
				'pagetriage-dot-separator',
				'pagetriage-articleinfo-stat',
				'pagetriage-bytes',
				'pagetriage-edits',
				'pagetriage-categories',
				'pagetriage-add-tag-confirmation',
				'pagetriage-tag-deletion-error',
				'pagetriage-toolbar-close',
				'pagetriage-toolbar-minimize',
				'pagetriage-tag-warning-notice'
			],
		];

		if ( ExtensionRegistry::getInstance()->isLoaded( 'WikiLove' ) ) {
			$tools[] = 'ext.pageTriage.views.toolbar/ext.pageTriage.wikilove.js';
			$viewsToolbarModule['styles'][] = 'ext.pageTriage.views.toolbar/ext.pageTriage.wikilove.css';
			$viewsToolbarModule['messages'] = array_merge( $viewsToolbarModule['messages'], [
				'pagetriage-wikilove-page-creator',
				'pagetriage-wikilove-edit-count',
				'pagetriage-wikilove-helptext',
				'pagetriage-wikilove-no-recipients',
				'pagetriage-wikilove-tooltip',
				'wikilove',
				'wikilove-button-send',
			] );
		}

		$viewsToolbarModule['scripts'] = array_merge(
			$toolBaseClass,
			$tools,
			$afterTools
		);

		$resourceLoader->register( 'ext.pageTriage.views.toolbar', $viewsToolbarModule );
	}

	/**
	 * Add PageTriage events to Echo
	 *
	 * @param $notifications array a list of enabled echo events
	 * @param $notificationCategories array details for echo events
	 * @param $icons array of icon details
	 * @return bool
	 */
	public static function onBeforeCreateEchoEvent(
		&$notifications, &$notificationCategories, &$icons
	) {
		global $wgPageTriageEnabledEchoEvents;

		if ( $wgPageTriageEnabledEchoEvents ) {
			$notificationCategories['page-review'] = [
				'priority' => 8,
				'tooltip' => 'echo-pref-tooltip-page-review',
			];
		}

		if ( in_array( 'pagetriage-mark-as-reviewed', $wgPageTriageEnabledEchoEvents ) ) {
			$notifications['pagetriage-mark-as-reviewed'] = [
				'presentation-model' => 'PageTriageMarkAsReviewedPresentationModel',
				'category' => 'page-review',
				'group' => 'neutral',
				'section' => 'message',
			];
		}
		if ( in_array( 'pagetriage-add-maintenance-tag', $wgPageTriageEnabledEchoEvents ) ) {
			$notifications['pagetriage-add-maintenance-tag'] = [
				'presentation-model' => 'PageTriageAddMaintenanceTagPresentationModel',
				'category' => 'page-review',
				'group' => 'neutral',
				'section' => 'alert',
			];
		}
		if ( in_array( 'pagetriage-add-deletion-tag', $wgPageTriageEnabledEchoEvents ) ) {
			$notifications['pagetriage-add-deletion-tag'] = [
				'presentation-model' => 'PageTriageAddDeletionTagPresentationModel',
				'category' => 'page-review',
				'group' => 'negative',
				'section' => 'alert',
			];
		}

		return true;
	}

	/**
	 * Add users to be notified on an echo event
	 * @param $event EchoEvent
	 * @param $users array
	 * @return bool
	 */
	public static function onEchoGetDefaultNotifiedUsers( $event, &$users ) {
		switch ( $event->getType() ) {
			// notify the page creator/starter
			case 'pagetriage-mark-as-reviewed':
			case 'pagetriage-add-maintenance-tag':
			case 'pagetriage-add-deletion-tag':
				if ( !$event->getTitle() ) {
					break;
				}

				$pageId = $event->getTitle()->getArticleID();

				$articleMetadata = new ArticleMetadata( [ $pageId ], false, DB_SLAVE );
				$metaData = $articleMetadata->getMetadata();

				if ( !$metaData ) {
					break;
				}

				if ( $metaData[$pageId]['user_id'] ) {
					$users[$metaData[$pageId]['user_id']] = User::newFromId( $metaData[$pageId]['user_id'] );
				}
			break;
		}
		return true;
	}

	/**
	 * Handler for LocalUserCreated hook
	 * @see http://www.mediawiki.org/wiki/Manual:Hooks/LocalUserCreated
	 * @param $user User object that was created.
	 * @param $autocreated bool True when account was auto-created
	 * @return bool
	 */
	public static function onLocalUserCreated( $user, $autocreated ) {
		// New users get echo preferences set that are not the default settings for existing users.
		// Specifically, new users are opted into email notifications for page reviews.
		if ( !$autocreated ) {
			$user->setOption( 'echo-subscriptions-email-page-review', true );
			$user->saveSettings();
		}
		return true;
	}

	public static function onUserMergeAccountFields( array &$updateFields ) {
		$updateFields[] = [ 'pagetriage_log', 'ptrl_user_id' ];
		$updateFields[] = [ 'pagetriage_page', 'ptrp_last_reviewed_by' ];

		return true;
	}

	/**
	 * @param $updater DatabaseUpdater
	 * @return bool
	 */
	public static function onLoadExtensionSchemaUpdates( $updater = null ) {
		$base = __DIR__ . "/sql";
		// tables
		$updater->addExtensionTable( 'pagetriage_tags', $base . '/PageTriageTags.sql' );
		$updater->addExtensionTable( 'pagetriage_page_tags', $base . '/PageTriagePageTags.sql' );
		$updater->addExtensionTable( 'pagetriage_page', $base . '/PageTriagePage.sql' );
		$updater->addExtensionTable( 'pagetriage_log', $base . '/PageTriageLog.sql' );

		// patches
		$updater->addExtensionIndex(
			'pagetriage_page',
			'ptrp_reviewed_updated',
			$base . '/PageTriagePagePatch.sql'
		);
		$updater->dropExtensionField(
			'pagetriage_log',
			'ptrl_comment',
			$base . '/PageTriageLogPatch_Drop_ptrl_comment.sql'
		);

		return true;
	}
}
