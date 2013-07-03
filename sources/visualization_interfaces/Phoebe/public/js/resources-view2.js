var progressbar = new ProgressBar();
var resources = [];
var groupedProperties = ["slice", "network_address", "cpu"];
var datas = [];
var current_server = location.protocol + '//' + location.hostname + (location.port ? ':' + location.port : '');

var margin = {top: 19, right: 20, bottom: 20, left: 19},
    //width = 960 - margin.right - margin.left,
    w = $("#vis").width(),
    h = 500 - margin.top - margin.bottom,
    cellSize = 48,
    resourcesPerLine = Math.floor(w / cellSize);

var div = d3.select("#vis");
var duration = 1000;

var vis = div.append("svg")
    .attr("width", w + margin.right + margin.left)
    .attr("height", h + margin.top + margin.bottom)
    .append("g");

$(document).ready(function() {
  getResources();
});

function getResources() {
  progressbar.start();
  $.ajax({
    type: "GET",
    url: current_server + "/oarapi/resources/full.json",
    dataType: "json",
    crossDomain: true,
    error: resources_error,
    success: resources_ready });
}

function resources_error(request, error) {
  $("#alert-content-span")[0].innerHTML="<Strong>Getting resources list:</strong> " + error;
  $("#alert-row").show("speed");
}

function resources_ready(response) {
  progressbar.stop();

  $.each(groupedProperties, function(oarProperty) {
    response.items.sort( function(a, b) {
      if (a[oarProperty] < b[oarProperty]) {
        return -1;
      }
      if (a[oarProperty] > b[oarProperty]) {
        return 1;
      }
      return 0;
    });
  });

  resources = response.items;
  drawView();
  getRunningJobs();
}

function getRunningJobs() {
  progressbar.start();
  $.ajax({
    type: "GET",
    url: current_server + "/oarapi/jobs/details.json",
    dataType: "json",
    data: { "state": "Running" },
    crossDomain: true,
    success: jobs_datas_ready });
}

function jobs_datas_ready(response) {
  progressbar.stop();
  if (response.total > 0) {
    $.each(response.items, function(i1, job) {
      $.each(job.resources, function(i2, resource) {
        vis.select("rect[resid='" + resource.id + "']")
          .transition()
          .duration(duration)
          .style("fill", function(d) { return jobColor(d); });
      });
    });
  }
}

function jobColor(d) {
  baseColor = "#3E97D1";
  c = d3.hsl(baseColor);
  //return d3.hsl(c.h - 30 + (d.id % 60) + (d.id % 5) , c.s * ( (0.1 * (d.id % 10)) + 1 ) , c.l * ( (0.1 * (d.id % 8)) + 1 ));
  return d3.hsl(c.h + (Math.sin((d.id) * 60) * 60), c.s, c.l);
}

function drawView() {
  var rect = vis.selectAll("rect")
    .data(resources)
    .enter().append("rect")
    .attr("id", function(d, i) { return i; })
    .attr("class", "mresource")
    .attr("resid", function(d) { return d.id; })
    .attr("width", cellSize)
    .attr("height", cellSize)
    .attr("x", function(d, i) { return (i * cellSize) % (resourcesPerLine * cellSize) ; })
    .attr("y", function(d, i) { return Math.floor(i / resourcesPerLine) * cellSize; });

  $.each(groupedProperties, function(i, oarProperty) {
    console.log(oarProperty);
    rect.attr(oarProperty, function(d) { return d[oarProperty]; });
  });

  rect
    .transition()
    .duration(duration)
    .style("fill", function(d) { return statuscolor(d.state); })


}

function statuscolor(state) {
  color="#eee";
  switch(state) {
    case "Alive":
      color = "#CDF76F";
      break;
    case "Suspected":
      color = "#EE6B9C";
      break;
    case "Absent":
      color = "#FF7640";
      break;
    case "Dead":
      color = "#000";
      break;
    default:
      color = "#eee";
      break;
  }
  return color;
}

