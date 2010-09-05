package Job;

sub new
{
  my ($class) = @_;
  my $self = {};
  bless $self, $class;
  return $self;
}
sub new_from_hash
{
  my ($clasa, $self) = @_;
  bless $self, $class;
  return $self;
}
1
