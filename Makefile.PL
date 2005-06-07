# $Id: Makefile.PL,v 3.9 2005/04/14 19:23:16 chris Exp $

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
			  'NAME'	=> 'POE::Component::AI::MegaHAL',
			  'PREREQ_PM' => {
							  'POE'    => 0.31,
							  'Carp'   => 0,
							  'AI::MegaHAL' => 0.04,
							 },
			  'VERSION_FROM' => 'lib/POE/Component/AI/MegaHAL.pm', # finds $VERSION
			  'dist' => { 'COMPRESS' => 'gzip --best' },
			 );

