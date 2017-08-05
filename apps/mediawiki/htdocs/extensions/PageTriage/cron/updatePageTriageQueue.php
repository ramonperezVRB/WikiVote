<?php

$IP = getenv( 'MW_INSTALL_PATH' );
if ( $IP === false ) {
	$IP = __DIR__ . '/../../..';
}
require_once "$IP/maintenance/Maintenance.php";

/**
 * A maintenance script that updates expired page metadata
 */
class UpdatePageTriageQueue extends Maintenance {

	/**
	 * Max number of article to process at a time
	 * @var int
	 */
	protected $batchSize = 100;

	/**
	 * @var DatabaseBase
	 */
	protected $dbr, $dbw;

	public function __construct() {
		parent::__construct();
		$this->mDescription = "Remove reviewed pages from pagetriage queue if they"
			. " are older then 30 days";
	}

	protected function init() {
		$this->dbr = wfGetDB( DB_SLAVE );
		$this->dbw = wfGetDB( DB_MASTER );
	}

	public function execute() {
		$this->init();
		$this->output( "Started processing... \n" );

		// Scan for data with ptrp_created set more than 30 days ago
		$startTime = wfTimestamp( TS_UNIX ) - 30 * 60 * 60 * 24;
		$count = $this->batchSize;

		$row = $this->dbr->selectRow(
			[ 'pagetriage_page' ],
			[ 'MAX(ptrp_page_id) AS max_id' ],
			[],
			__METHOD__
		);

		// No data to process, exit
		if ( $row === false ) {
			$this->output( "No data to process \n" );
			return;
		}

		$startId = $row->max_id + 1;

		while ( $count === $this->batchSize ) {
			$count = 0;
			$startTime = $this->dbr->addQuotes( $this->dbr->timestamp( $startTime ) );
			$startId = (int)$startId;

			// Remove pages older than 30 days, if
			// 1. the page has been reviewed, or
			// 2. the page is not in main namespace or
			// 3. the page is a redirect
			$res = $this->dbr->select(
				[ 'pagetriage_page', 'page' ],
				[ 'ptrp_page_id', 'ptrp_created', 'page_namespace', 'ptrp_reviewed' ],
				[
					'(ptrp_created < ' . $startTime . ') OR
					(ptrp_created = ' . $startTime . ' AND ptrp_page_id < ' . $startId . ')',
					'ptrp_page_id = page_id',
					'page_namespace != 0 OR ptrp_reviewed > 0 OR page_is_redirect = 1'
				],
				__METHOD__,
				[ 'LIMIT' => $this->batchSize, 'ORDER BY' => 'ptrp_created DESC, ptrp_page_id DESC' ]
			);

			$pageId = [];
			foreach ( $res as $row ) {
				$pageId[] = $row->ptrp_page_id;
				$count++;
			}

			if ( $pageId ) {
				// update data from last row
				if ( $row->ptrp_created ) {
					$startTime = wfTimestamp( TS_UNIX, $row->ptrp_created );
				}
				$startId = $row->ptrp_page_id;

				$this->beginTransaction( $this->dbw, __METHOD__ );

				$this->dbw->delete(
						'pagetriage_page',
						[ 'ptrp_page_id' => $pageId ],
						__METHOD__,
						[]
				);
				$this->dbw->delete(
						'pagetriage_log',
						[ 'ptrl_page_id' => $pageId ],
						__METHOD__,
						[]
				);
				$articleMetadata = new ArticleMetadata( $pageId );
				$articleMetadata->deleteMetadata();

				$this->commitTransaction( $this->dbw, __METHOD__ );
			}

			$this->output( "processed $count \n" );
			wfWaitForSlaves();
		}

		$this->output( "Completed \n" );
	}
}

$maintClass = "UpdatePageTriageQueue";
require_once DO_MAINTENANCE;
