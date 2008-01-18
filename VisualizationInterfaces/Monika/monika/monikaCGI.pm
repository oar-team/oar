## This package inherits CGI.pm and adds support for color management

package monika::monikaCGI;
use strict;
use File::Basename;
use monika::Sort::Naturally;
#use warnings;
use base qw(CGI);
use Data::Dumper;

## class constructor
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new();
  $self->{USED_COLORS} = {};
  $self->{COLOR_POOL}  = [];
  bless ($self, $class);
  return $self;
}

## get the color for a key
sub getColor {
  my $self = shift;
  my $key = shift;
  if (not $self->{USED_COLORS}->{$key}) {
    $self->{USED_COLORS}->{$key} = $self->getColorFromPool($key);
  }
  return $self->{USED_COLORS}->{$key};
}

## set a color for a key
sub setColor {
  my $self = shift;
  my $key = shift;
  my $color = shift;
  $self->{USED_COLORS}->{$key} = $color;
  return 1;
}

## set color pool
sub setColorPool {
  my $self = shift;
  $self->{COLOR_POOL} = shift;
  return 1;
}

## get a color from color pool, and rotate the pool by one.
sub getColorFromPool {
  my $self = shift;
  my $key = shift;
  my $color_pool = $self->{COLOR_POOL};
  my $color = $color_pool->[$key % ($#{@$color_pool}+1)];
  #my $color = shift @$color_pool;
  #push @$color_pool,$color;
  return $color;
}

## print a HTML <TD> with a background color corresponding to the text
## given as parameter
sub colorTd {
  my $self = shift;
  my $txt = shift;
  my $width;
  my $href;
  my $title;
  if (@_) {
    $width = shift;
  } else {
    $width = undef;
  }
  if (@_) {
    $href = shift;
  } else {
    $href = undef;
  }
  if (@_) {
    $title = shift;
  } else {
    $title = undef;
  }
  my $txt2;
  if ($href) {
    $txt2 = $self->a({-href => $href,
		      -title => $title
		     },
		     $self->b($txt)
		    );
  } else {
    $txt2 = $self->b($txt);
  }
  return $self->td({
		    -bgcolor => $self->getColor($txt),
		    -width => $width,
		    -align => "center"
		   }, $txt2);
}

# print a HTML <TD> with a background color corresponding to the text
## given as parameter
sub colorjavascriptTd {
  my $self = shift;
  my $txt = shift;
  my $width;
  my $href;
  my $title;
  my $javascript;
  if (@_) {
    $width = shift;
  } else {
    $width = undef;
  }
  if (@_) {
    $javascript = shift;
  } else {
    $javascript = undef;
  }
  if (@_) {
    $href = shift;
  } else {
    $href = undef;
  }
  if (@_) {
    $title = shift;
  } else {
    $title = undef;
  }
  
  my $txt2;
  if ($href) {
    $txt2 = $self->a({-href => $href,
		      -title => $title,
		     },
		     $self->b($txt)
		    );
  } else {
    $txt2 = $self->b($txt);
  }
  if ($javascript) {
      return $self->td({-class => "fixed_td",
		   -bgcolor => $self->getColor($txt),
		    -width => $width,
		    -align => "center",
            -onmouseout => "return nd()",
            -onmouseover => "return overlib('$javascript')"
		   }, $txt2);
  } else {   
      return $self->td({
		    -bgcolor => $self->getColor($txt),
		    -width => $width,
		    -align => "center"
		   }, $txt2);
  }
 }


## debug function: show color settings
sub colorTable {
  my $self = shift;
  my $output = "";
  $output .= $self->start_table({-border => "1", -align => "center"});
  foreach my $key (keys %{$self->{USED_COLORS}}) {
    $output .= $self->start_Tr();
    $output .= $self->td({-bgcolor => $self->{USED_COLORS}->{$key}, -width => "20"},"");
    $output .= $self->td({-align => "center"},$key);
    $output .= $self->end_Tr();
  }
  my $i=0;
  foreach my $color (@{$self->{COLOR_POOL}}) {
    $output .= $self->start_Tr();
    $output .= $self->td({-bgcolor => $color, -width => "20"},"");
    $output .= $self->td({-align => "center"},"Pool ".$i++);
    $output .= $self->end_Tr();

  }
  $output .= $self->end_table();
}

sub nodeReservationTable {
  my $self = shift;
  my $nodes = shift;
  my $nodelist = shift;
  my $output = "";
  my @names;
  if (defined $nodelist) {
    @names = @$nodelist;
  } else {
    @names = keys %$nodes;
  }
  my $is_sorted = 1;
  #@names = sort {$a <=> $b or $a cmp $b} @names or $is_sorted = 0;
  @names = sort {$a <=> $b or Sort::Naturally::ncmp($a,$b)} @names or $is_sorted = 0;
  $output .= $self->start_table({-border=>"1",
				 -align => "center"
				});
  $output .= $self->start_Tr();
  my $i=1;
  ## each nodes get printed in the right order
  foreach my $name (@names) {
#    $output .= $self->start_td({-align => "center",});
#	$output .= $self->start_form({ action => "input_button.htm"});
#	$output .= $self->start_form();
#	$output .= $self->input({
#							type => "button",
#							name => "lien",
#							value => "$name",
#							onclick => "self.location.href = '".$self->self_url(-query=>0)."?node=".$name."'"
#							});
#	$output .= $self->endform();
#	$output .= $self->end_td({-align => "center",});

    $output .= $self->start_td({-align => "center",
			       });
    #$output .= $self->b($self->small($self->small($self->a({ -href => $self->self_url(-query=>0)."?node=".$name,
    my $cgiName = File::Basename::basename($self->self_url(-query=>0));
    $output .= $self->b($self->small($self->small($self->a({ -href => $cgiName."?node=".$name, -title => "click to see node details" },$$nodes{$name}->displayHTMLname()))));
    $output .= $self->end_td();

    $output .= $self->start_td();
    ## print this node status sub table
    $output .= $$nodes{$name}->htmlTable($self);
    $output .= $self->end_td();
    ## 10 nodes per line
    if ($i++ % monika::Conf::myself()->nodes_per_line() == 0) {
      $output .= $self->end_Tr();
      $output .= $self->start_Tr();
    }
  }
  $output .= $self->end_Tr();
  $output .= $self->end_table();
#  $output .= $self->endform();

  return $output;
}


## print page head
sub page_head {
  my $self = shift;
  my $title = shift;
  my $output = "";

  $output .= $self->header();
  $output .= $self->start_html(-title => $title,
			       -link => "black",
			       -vlink => "black",
			       -alink => "darkblue"
			      );
}


## that's all
return 1;
