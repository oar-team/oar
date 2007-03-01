# $Id$
use sorted_chained_list;
use Data::Dumper;

my $c = sorted_chained_list::new();

sorted_chained_list::add_element($c, 3, undef);
sorted_chained_list::add_element($c, undef, undef);
sorted_chained_list::add_element($c, 2, undef);
sorted_chained_list::add_element($c, -2, undef);
sorted_chained_list::add_element($c, 10, undef);
sorted_chained_list::add_element($c, 3, undef);
sorted_chained_list::add_element($c, 20, undef);
sorted_chained_list::add_element($c, 0, undef);
sorted_chained_list::add_element($c, undef, undef);
sorted_chained_list::add_element($c, 2, undef);
print(Dumper($c));


print(sorted_chained_list::pretty_print($c)."\n");
