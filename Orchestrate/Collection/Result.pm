package Orchestrate::Collection::Result;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;

has [qw(orchestrate collection data key ref etag timestamp ordinal column_names)];

sub delete {
  my ($self, %opts) = @_;

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->collection->url->clone;
  my $key         = $self->key;

  $url->path($key);

  $url->query(purge => 'true') if ( $opts{purge} );
  my $tx = $ua->build_tx(DELETE => $url);

  unless ( $opts{ignore_ref} ) {
    $tx->req->headers->add('If-Match' => $self->etag);
  }

  $tx = $ua->start($tx);

  croak $tx->res->json->{message} unless $tx->success;

  return;
}

sub update {
  my ($self,%opts) = @_;

  return unless $opts{data};

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->collection->url->clone;

  $url->path($self->key);

  my $tx = $ua->build_tx(PUT => $url => json => $opts{data});

  unless ( $opts{ignore_ref} ) {
    $tx->req->headers->add('If-Match' => $self->etag);
  }

  $tx = $ua->start($tx);

  croak $tx->res->json->{message} unless $tx->success;

  my $path = Mojo::Path->new($tx->res->headers->location);
  my ($key, $ref) = (@{$path->parts})[2, 4];

  $self->key($key);
  $self->ref($ref);
  $self->etag($tx->res->headers->etag);

  return $self;

}

sub get_related {
  my ($self,%opts) = @_;

  return unless $opts{kinds} and ref $opts{kinds} eq 'ARRAY';

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;
  my $key         = $self->key;

  $url->path($key.'/relations/');

  for ( @{ $opts{kinds} } ) {
    push @{$url->path}, $_;
  }
  $url->path->trailing_slash(0);
  delete $opts{kinds};

  for ( keys %opts ) {
    $url->query({$_ => $opts{$_}});
  }

  my $ua   = $orchestrate->ua;
  my $tx   = $ua->get($url);
  my $data = $tx->res->json;

  croak $data->{message} unless $tx->success;

  my @columns = keys %{$data->{results}->[0]->{value}};
  my $total   = $data->{count};

  return Orchestrate::Collection::ResultSet->new(
    orchestrate  => $orchestrate,
    collection   => $self,
    data         => $data,
    next_data    => $data,
    column_names => \@columns,
    total        => $total,
  );
}

sub create_related {
  my ($self,%opts) = @_;

  return unless $opts{kind};
  return unless $opts{to_collection};
  return unless $opts{to_key};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;
  my $key         = $self->key;

  $url->path($key.'/relation/');
  $url->path($opts{kind}.'/'.$opts{to_collection}.'/'.$opts{to_key});

  say $url;
  my $ua   = $orchestrate->ua;
  my $tx   = $ua->put($url);

  croak $tx->res->json->{message} unless $tx->success;

  return;
}

sub delete_related {
  my ($self,%opts) = @_;


  return unless $opts{kind};
  return unless $opts{to_collection};
  return unless $opts{to_key};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;
  my $key         = $self->key;

  $url->path($key.'/relation/');
  $url->path($opts{kind}.'/'.$opts{to_collection}.'/'.$opts{to_key});

  $url->query(purge => 'true') if $opts{purge};

  my $ua   = $orchestrate->ua;
  my $tx   = $ua->delete($url);

  croak $tx->res->json->{message} unless $tx->success;

  return;

}
sub columns {
  return @{shift->column_names};
}

1;