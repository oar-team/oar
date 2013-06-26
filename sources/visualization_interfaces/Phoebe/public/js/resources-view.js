var progressbar = new ProgressBar();
var wheel_hash = {};
var wheel_datas = [];
var current_server = location.protocol + '//' + location.hostname + (location.port ? ':' + location.port : '');

var w = 840,
    h = w,
    r = w / 2,
    x = d3.scale.linear().range([0, 2 * Math.PI]),
    y = d3.scale.pow().exponent(1.3).domain([0, 1]).range([0, r]),
    p = 5,
    duration = 1000;

var div = d3.select("#vis");

div.select("img").remove();

div.append("p")
    .attr("id", "intro")
    .text("Click on segment to zoom!");

var partition = d3.layout.partition()
    .sort(null)
    .value(function(d) { return 5.8 - d.depth; });

var arc = d3.svg.arc()
    .startAngle(function(d) { return Math.max(0, Math.min(2 * Math.PI, x(d.x))); })
    .endAngle(function(d) { return Math.max(0, Math.min(2 * Math.PI, x(d.x + d.dx))); })
    .innerRadius(function(d) { return Math.max(0, d.y ? y(d.y) : d.y); })
    .outerRadius(function(d) { return Math.max(0, y(d.y + d.dy)); });


var vis = div.append("svg")
    .attr("width", w + p * 2)
    .attr("height", h + p * 2)
    .append("g")
    .attr("transform", "translate(" + (r + p) + "," + (r + p) + ")");

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
    $.each(response.items, function(i1, item) {
      $.each(item.resources, function(i2, resource) {
        vis.select("path[resid='" + resource.id + "']").transition().duration(duration).style("fill", "#3E97D1");
      //   vis.)elect("tspan[resid='" + resource.id + "']").transition().duration(duration).tween("text", function() {
      //     var i = d3.interpolate(this.textContent, item.id);
      //     return function(t) {
      //       this.textContent = i(t);
      //     };
      //   });
        vis.select("tspan[resid='" + resource.id + "']").transition().delay(duration).text(item.owner);
      });
    });
  }
}

function resources_ready(response) {
  progressbar.stop();
  $.each(response.items, function(i, item) {
    var nodename = item.network_address.split(".")[0];
    var cluster = item.slice;
    var cpu = item.cpu;
    var core = item.cpuset;
    if (wheel_hash[cluster] == undefined) {
      wheel_hash[cluster] = {};
    }
    if (wheel_hash[cluster][nodename] == undefined) {
      wheel_hash[cluster][nodename] = {};
    }
    if (wheel_hash[cluster][nodename][cpu] == undefined) {
      wheel_hash[cluster][nodename][cpu] = {};
    }
    if (wheel_hash[cluster][nodename][cpu][core] == undefined) {
      wheel_hash[cluster][nodename][cpu][core] = { "status": item.state, "id": item.id };
    }
  });

  $.each(wheel_hash, function(clustername, nodes) {
    cluster = {};
    cluster["name"] = clustername;
    cluster["children"] = [];
    $.each(nodes, function(nodename, cpus) {
        node = { "name": nodename, "children": [] };
        $.each(cpus, function(cpuid, cores) {
          cpu = { "name": "cpu-" + cpuid, "children": [] };
          $.each(cores, function(coreid, value) {
            core = { "name": statusname(value.status), "colour": statuscolor(value.status), "id": value.id };
            cpu["children"].push(core);
          });
          node["children"].push(cpu);
        });
        cluster["children"].push(node);
    });
    wheel_datas.push(cluster);
  });

  drawMonika();
  getRunningJobs();

}

function resources_error(request, error) {
  $("#alert-content-span")[0].innerHTML="<Strong>Getting resources list:</strong> " + error;
  $("#alert-row").show("speed");
}

$(document).ready(function() {
  getResources();
});

function statusname(state) {
  switch(state) {
    case "Alive":
      name = "Free";
      break;
    case "Suspected":
      name = "Suspected";
      break;
    case "Absent":
      name = "Absent";
      break;
    case "Dead":
      name = "Unavailable";
      break;
    default:
      name = "Unknown";
      break;
  }
  return name;
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


function drawMonika() {
    var nodes = partition.nodes({children: wheel_datas});

  var path = vis.selectAll("path").data(nodes);
  path.enter().append("path")
      .attr("id", function(d, i) { return "path-" + i; })
      .attr("d", arc)
      .attr("resid", function(d) { if (d.id != undefined) { return d.id; } })
      .attr("fill-rule", "evenodd")
      .style("fill", colour)
      .on("click", click);

  var text = vis.selectAll("text").data(nodes);
  var textEnter = text.enter().append("text")
      .style("fill-opacity", 1)
      .style("fill", function(d) {
        return brightness(d3.rgb(colour(d))) < 125 ? "#eee" : "#000";
      })
      .attr("text-anchor", function(d) {
        return x(d.x + d.dx / 2) > Math.PI ? "end" : "start";
      })
      .attr("dy", ".2em")
      .attr("transform", function(d) {
        var multiline = (d.name || "").split(" ").length > 1,
            angle = x(d.x + d.dx / 2) * 180 / Math.PI - 90,
            rotate = angle + (multiline ? -.5 : 0);
        return "rotate(" + rotate + ")translate(" + (y(d.y) + p) + ")rotate(" + (angle > 90 ? -180 : 0) + ")";
      })
      .on("click", click);
  textEnter.append("tspan")
      .attr("x", 0)
      .attr("resid", function(d) { if (d.id != undefined) { return d.id; } })
      .text(function(d) { return d.depth ? d.name.split(" ")[0] : ""; });
  textEnter.append("tspan")
      .attr("x", 0)
      .attr("dy", "1em")
      .text(function(d) { return d.depth ? d.name.split(" ")[1] || "" : ""; });

  function click(d) {
    path.transition()
      .duration(duration)
      .attrTween("d", arcTween(d));

    // Somewhat of a hack as we rely on arcTween updating the scales.
    text
      .style("visibility", function(e) {
        return isParentOf(d, e) ? null : d3.select(this).style("visibility");
      })
      .transition().duration(duration)
      .attrTween("text-anchor", function(d) {
        return function() {
          return x(d.x + d.dx / 2) > Math.PI ? "end" : "start";
        };
      })
      .attrTween("transform", function(d) {
        var multiline = (d.name || "").split(" ").length > 1;
        return function() {
          var angle = x(d.x + d.dx / 2) * 180 / Math.PI - 90,
              rotate = angle + (multiline ? -.5 : 0);
          return "rotate(" + rotate + ")translate(" + (y(d.y) + p) + ")rotate(" + (angle > 90 ? -180 : 0) + ")";
        };
      })
      .style("fill-opacity", function(e) { return isParentOf(d, e) ? 1 : 1e-6; })
      .each("end", function(e) {
        d3.select(this).style("visibility", isParentOf(d, e) ? null : "hidden");
      });
  }

}

function isParentOf(p, c) {
  if (p === c) return true;
  if (p.children) {
    return p.children.some(function(d) {
      return isParentOf(d, c);
    });
  }
  return false;
}

function colour(d) {
  if (d.children) {
    // There is a maximum of two children!
    var colours = d.children.map(colour),
        a = d3.hsl(colours[0]),
        b = d3.hsl(colours[1]);
    // L*a*b* might be better here...
    return d3.hsl((a.h + b.h) / 2, a.s * 1.2, a.l / 1.2);
  }
  return d.colour || "#fff";
}

// Interpolate the scales!
function arcTween(d) {
  var my = maxY(d),
      xd = d3.interpolate(x.domain(), [d.x, d.x + d.dx]),
      yd = d3.interpolate(y.domain(), [d.y, my]),
      yr = d3.interpolate(y.range(), [d.y ? 20 : 0, r]);
  return function(d) {
    return function(t) { x.domain(xd(t)); y.domain(yd(t)).range(yr(t)); return arc(d); };
  };
}

function maxY(d) {
  return d.children ? Math.max.apply(Math, d.children.map(maxY)) : d.y + d.dy;
}

// http://www.w3.org/WAI/ER/WD-AERT/#color-contrast
function brightness(rgb) {
  return rgb.r * 0.299 + rgb.g * 0.587 + rgb.b * 0.114;
}
