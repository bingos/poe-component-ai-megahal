use inc::Module::Install;
name 'POE-Component-AI-MegaHAL';
license 'perl';
author 'Chris Williams <chris@bingosnet.co.uk>';
version_from 'lib/POE/Component/AI/MegaHAL.pm';
requires 'POE' => 0.38;
requires 'Carp' => 0;
requires 'AI::MegaHAL' => 0.05;
WriteAll();
