<?php

require_once __DIR__ . '/../../../includes/utils/AutoloadGenerator.php';

// @codingStandardsIgnoreStart
function main() {
// @codingStandardsIgnoreEnd
	$base = dirname( __DIR__ );
	$generator = new AutoloadGenerator( $base );
	$dirs = [
		'includes',
		'tests',
		'maintenance',
	];
	foreach ( $dirs as $dir ) {
		$generator->readDir( $base . '/' . $dir );
	}
	foreach ( glob( $base . '/*.php' ) as $file ) {
		$generator->readFile( $file );
	}

	$target = $generator->getTargetFileInfo();

	file_put_contents(
		$target['filename'],
		$generator->getAutoload( basename( __DIR__ ) . '/' . basename( __FILE__ ) )
	);

	echo "Done.\n\n";
}

main();
