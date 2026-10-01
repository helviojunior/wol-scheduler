<?php
/*
 * wolscheduler_status.php
 *
 * Shows live state of the wolscheduler daemon and allows sending a WOL now.
 */

##|+PRIV
##|*IDENT=page-services-wolscheduler
##|*NAME=Services: WOL Scheduler
##|*DESCR=Allow access to the 'Services: WOL Scheduler' page.
##|*MATCH=wolscheduler_status.php*
##|-PRIV

require_once("guiconfig.inc");
require_once("/usr/local/pkg/wolscheduler.inc");

$hosts = wolscheduler_hosts();
$savemsg = null;

if ($_POST['wake'] !== null && isset($hosts[$_POST['id']])) {
	$h = $hosts[$_POST['id']];
	if (wolscheduler_send_now($h)) {
		$savemsg = sprintf(gettext("Magic packet sent to %s (%s)."), htmlspecialchars($h['descr']), htmlspecialchars($h['mac']));
		$savetype = 'success';
	} else {
		$savemsg = sprintf(gettext("Failed to send magic packet to %s."), htmlspecialchars($h['descr']));
		$savetype = 'danger';
	}
}

function wolsched_fmt_time($ts) {
	return ($ts > 0) ? date("Y-m-d H:i:s", $ts) : '-';
}

/* Index status rows by MAC + IP so they can be matched to config entries */
$status = array();
foreach (wolscheduler_status() as $row) {
	$status[strtolower($row['mac']) . '|' . $row['ip']] = $row;
}

$running = is_process_running("wolscheduler");

$pgtitle = array(gettext("Services"), gettext("WOL Scheduler"), gettext("Status"));
$pglinks = array("", "/pkg.php?xml=wolscheduler.xml", "@self");
include("head.inc");

if ($savemsg) {
	print_info_box($savemsg, $savetype);
}

$tab_array = array();
$tab_array[] = array(gettext("Hosts"), false, "/pkg.php?xml=wolscheduler.xml");
$tab_array[] = array(gettext("Status"), true, "/wolscheduler_status.php");
display_top_tabs($tab_array);
?>

<div class="panel panel-default">
	<div class="panel-heading">
		<h2 class="panel-title">
			<?=gettext("Daemon")?>:
			<?php if ($running): ?>
				<span class="text-success"><i class="fa fa-check-circle"></i> <?=gettext("running")?></span>
			<?php else: ?>
				<span class="text-danger"><i class="fa fa-times-circle"></i> <?=gettext("stopped")?></span>
			<?php endif; ?>
		</h2>
	</div>
	<div class="panel-body table-responsive">
		<table class="table table-striped table-hover table-condensed">
			<thead>
				<tr>
					<th><?=gettext("Description")?></th>
					<th><?=gettext("MAC")?></th>
					<th><?=gettext("IP")?></th>
					<th><?=gettext("State")?></th>
					<th><?=gettext("Last reply")?></th>
					<th><?=gettext("Last WOL")?></th>
					<th><?=gettext("WOLs sent")?></th>
					<th><?=gettext("Next scheduled WOL")?></th>
					<th><?=gettext("Actions")?></th>
				</tr>
			</thead>
			<tbody>
<?php foreach ($hosts as $id => $h):
	$ip = (!empty($h['keepalive']) && is_ipaddrv4($h['ipaddr'])) ? $h['ipaddr'] : '-';
	$st = $status[strtolower($h['mac']) . '|' . $ip];
	$state = empty($h['enable']) ? 'disabled' : ($st ? $st['state'] : 'n/a');
	switch ($state) {
		case 'up':       $badge = 'label-success'; break;
		case 'down':     $badge = 'label-danger'; break;
		case 'unknown':  $badge = 'label-warning'; break;
		default:         $badge = 'label-default';
	}
?>
				<tr>
					<td><?=htmlspecialchars($h['descr'])?></td>
					<td><?=htmlspecialchars($h['mac'])?></td>
					<td><?=htmlspecialchars($ip)?></td>
					<td><span class="label <?=$badge?>"><?=htmlspecialchars($state)?></span></td>
					<td><?=$st ? wolsched_fmt_time($st['last_reply']) : '-'?></td>
					<td><?=$st ? wolsched_fmt_time($st['last_wol']) : '-'?></td>
					<td><?=$st ? $st['wol_count'] : '-'?></td>
					<td><?=$st ? wolsched_fmt_time($st['next_wol']) : '-'?></td>
					<td>
						<form method="post" style="display:inline">
							<input type="hidden" name="id" value="<?=$id?>" />
							<button type="submit" name="wake" value="1" class="btn btn-xs btn-primary">
								<i class="fa fa-power-off"></i> <?=gettext("Wake now")?>
							</button>
						</form>
					</td>
				</tr>
<?php endforeach; ?>
<?php if (empty($hosts)): ?>
				<tr><td colspan="9"><?=gettext("No hosts configured.")?></td></tr>
<?php endif; ?>
			</tbody>
		</table>
	</div>
</div>

<script type="text/javascript">
//<![CDATA[
/* Auto-refresh every 10 seconds */
setTimeout(function() { window.location.href = window.location.pathname; }, 10000);
//]]>
</script>

<?php include("foot.inc"); ?>
