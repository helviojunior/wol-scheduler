<?php

global $priv_list;

$priv_list['page-services-wolscheduler'] = array();
$priv_list['page-services-wolscheduler']['name'] = "WebCfg - Services: WOL Scheduler";
$priv_list['page-services-wolscheduler']['descr'] = "Allow access to the WOL Scheduler package GUI.";
$priv_list['page-services-wolscheduler']['match'] = array();
$priv_list['page-services-wolscheduler']['match'][] = "pkg.php?xml=wolscheduler.xml*";
$priv_list['page-services-wolscheduler']['match'][] = "pkg_edit.php?xml=wolscheduler.xml*";
$priv_list['page-services-wolscheduler']['match'][] = "wolscheduler_status.php*";
