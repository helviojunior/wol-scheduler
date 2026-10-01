<?php
/*
 * Title-bar shortcuts for the WOL Scheduler pages (loaded by shortcuts.inc).
 * 'service' makes head.inc render the restart/stop (or start) buttons.
 */

global $shortcuts;

$shortcuts['wolscheduler'] = array();
$shortcuts['wolscheduler']['main'] = "wolscheduler_status.php";
$shortcuts['wolscheduler']['log'] = "status_logs.php?filtersubmit=1&filtertext=wolscheduler";
$shortcuts['wolscheduler']['service'] = "wolscheduler";
