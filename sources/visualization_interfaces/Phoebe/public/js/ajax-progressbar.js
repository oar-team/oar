function ProgressBar() {

  this.count = 0;

  this.start = function() {
    this.set("100%");
    $("#rest-progress div").show();
    this.count++;
  }

  this.stop = function() {
    this.count--;
    if (this.count == 0) {
      $("#rest-progress div").hide();
    }
  }

  this.set = function(value) {
    $("#rest-progress div div").css("width", value);
  }
}

