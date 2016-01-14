# Manage the evening, night and week-end job types
if (my @t = grep (qr/^(evening|night|week-end)=\d\d\d\d-\d\d-\d\d$/, @$type_list)) {
  ($slot,$day) = $t[0] =~ /^(evening|night|week-end)=(\d\d\d\d-\d\d-\d\d)$/;
  $queue_name = "night";
  if ($slot eq 'evening') {
    push @$type_list, ("postpone=$day 20:00:00","deadline=$day 25:00:00");
  } elsif ($slot eq 'night') {
    push @$type_list, ("postpone=$day 20:00:00","deadline=$day 32:00:00");
  } elsif ($slot eq 'week-end') {
    # TODO: verifier que day est bien un vendredi...
    push @$type_list, ("postpone=$day 20:00:00","deadline=$day 80:00:00");
  } else {
    die "This error should not happen !\n";
  }
}
