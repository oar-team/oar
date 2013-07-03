var current_jobs = { aaData: [] };
var waiting_jobs = { aaData: [] };
var total_jobs = 0;
var prefetch_waiting_jobs = true;
var progressbar = new ProgressBar();
var current_server = location.protocol + '//' + location.hostname + (location.port ? ':' + location.port : '');

var currentJobsTable = $("#current-jobs-table").dataTable({
  bPaginate: false,
  sPaginationType: "full_numbers",
  sDom: "<'row'<'span8'l><'span8'f>r>t<'row'<'span8'i><'span8'p>>",
  oLanguage: {
    "sLengthMenu": "_MENU_ jobs per page"
  }
});

var waitingJobsTable = $("#waiting-jobs-table").dataTable({
  bPaginate: true,
  sPaginationType: "full_numbers",
  sDom: "<'row'<'span8'l><'span8'f>r>t<'row'<'span8'i><'span8'p>>",
  oLanguage: {
    "sLengthMenu": "_MENU_ jobs per page"
  }
});

$.extend( $.fn.dataTableExt.oStdClasses, {
    "sWrapper": "dataTables_wrapper form-inline"
} );

function addToTable(response,table){
    $.each(response.aaData, function(i,item){
        var start_time = new Date(item.start_time * 1000);
        var bar_html = "";
        if (item.state == 'Running') {
          bar_value = (((+new Date) - (item.start_time * 1000)) / (item.walltime * 1000)) * 100;
          bar_html = "<div class=\"progress\" style=\"height: 12px;margin-bottom: 2px;margin-top: 2px;\"><div class=\"bar\" style=\"width: " + bar_value + "%;height: 12px;\"></div></div>";
        }
        table.fnAddData([
            item.state == 'Running' ? "<span class=\"label label-info\">" + item.id + "</span>" :  "<span class=\"label label\">" + item.id + "</span>",
            item.owner,
            item.state == 'Running' ? bar_html : item.state,
            item.name,
            item.queue,
            item.wanted_resources,
            item.walltime,
            //item.start_time == 0 ? "No prediction" : new Date(item.start_time * 1000)
            item.start_time == 0 ? "No prediction" : start_time.toLocaleString()
        ]);
    });
}

function populate_current_jobs(response) {
  current_jobs.aaData = current_jobs.aaData.concat(response.items);
  addToTable(current_jobs,currentJobsTable);
  $("#nb-current-jobs-span")[0].innerHTML=current_jobs.aaData.length + " jobs";
  if (current_jobs.aaData.length < response.total) {
    progressbar.set(((current_jobs.aaData.length / response.total) * 100) + "%");
    getJobs(500, current_jobs.aaData.length, 'Running,Launching,Finishing');
  } else {
    progressbar.stop();
    $("#current-jobs-refresh-btn").button("reset");
  }
}

function populate_waiting_jobs(response) {
  if (prefetch_waiting_jobs == false) {
    waiting_jobs.aaData = waiting_jobs.aaData.concat(response.items);
    addToTable(waiting_jobs,waitingJobsTable);
    $("#nb-waiting-jobs-span")[0].innerHTML=waiting_jobs.aaData.length + " jobs";
    if (waiting_jobs.aaData.length < response.total)  {
      progressbar.set(((waiting_jobs.aaData.length / response.total) * 100) + "%");
      getJobs(200, waiting_jobs.aaData.length, 'Running,Launching,Finishing');
    } else {
      progressbar.stop();
      $("#waiting-jobs-refresh-btn").button("reset");
      $("#waiting-jobs-refresh-btn")[0].innerHTML="<i class=\"icon-refresh\"></i> Refresh";
    }
  } else {
    $("#nb-waiting-jobs-span")[0].innerHTML=response.total + " jobs";
    progressbar.stop();
    $("#waiting-jobs-refresh-btn").button("reset");
    prefetch_waiting_jobs = false;
  }
}

function getJobs(limit, offset, state, jobs_method) {
  progressbar.start();
  $.ajax({
    type: "GET",
    url: current_server + "/oarapi/jobs/details.json",
    dataType: "json",
    data: { "state": state, "limit": limit, "offset": offset },
    crossDomain: true,
    success: jobs_method });
}

$(document).ready(function () {
  $("#waiting-jobs-row").hide();
  $("#current-jobs-refresh-btn").button("loading")
  //var refresh_interval = setInterval(getJobs(0,0,'Running,Launching,Finishing',populate_current_jobs),5000);
  getJobs(500,0,'Running,Launching,Finishing',populate_current_jobs)
  $("#waiting-jobs-refresh-btn").button("loading");
  getJobs(1,0,'Waiting',populate_waiting_jobs);
});

$("#current-jobs-refresh-btn").click(function() {
  currentJobsTable.fnClearTable();
  current_jobs = { aaData: [] };
  $("#nb-current-jobs-span")[0].innerHTML=current_jobs.aaData.length + " job";
  $(this).button("loading");
  getJobs(500,0,'Running,Launching,Finishing',populate_current_jobs);
});

$("#waiting-jobs-refresh-btn").click(function() {
  waitingJobsTable.fnClearTable();
  waiting_jobs = { aaData: [] };
  $("#nb-waiting-jobs-span")[0].innerHTML=waiting_jobs.aaData.length + " job";
  $(this).button("loading");
  if (prefetch_waiting_jobs == false) {
    $("#waiting-jobs-row").show('fast');
  }
  getJobs(50,0,'Waiting',populate_waiting_jobs);
});

