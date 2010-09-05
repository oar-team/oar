package OarClient;

sub new
{
  my ($class) = @_;
  my $client = REST::Client->new;
  my $self = { _client => $client };
  bless $self, $class;
  return $self;
}
sub new_from_client
{
  my ($class, $client) = @_;
  my $self = { _client => $client };
  bless $self, $class;
  return $self;
}
sub get_jobs_to_run
{
  my ($self) = @_;
  my $client = $self->{_client};
  $client->GET('http://192.168.56.101/oarapi/resources/nodes/node2/jobs.json');
  print $client->responseContent;
}

1
