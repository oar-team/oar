package JobList;

sub new 
{
  my ($class, $hashref) = @_;
  my @list = values %$hashref;
  my $self = \@list;
  bless $self, $class;
  return $self;
}
1
