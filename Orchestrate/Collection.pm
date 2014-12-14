package Orchestrate::Collection;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;
use Mojo::JSON qw(encode_json);
use Orchestrate::Collection::ResultSet;
use Orchestrate::Collection::Result;

has [qw(orchestrate name url error)];

sub find {
  my $self = shift;

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->url->clone;

  if (@_ > 1) {
    $url->path(shift . '/ref/' . shift);
  }
  elsif (@_) {
    $url->path(shift);
  }
  else {
    return;
  }

  my $tx   = $ua->get($url);
  my $data = $tx->res->json;

  croak $data->{message} unless $tx->success;

  $self->error($data->{message}) and return $self unless $tx->success;

  my $path = Mojo::Path->new($tx->res->headers->content_location);
  my ($key, $ref) = (@{$path->parts})[2, 4];

  my @columns = keys %{$data};
  my $etag    = $tx->res->headers->etag;

  return Orchestrate::Collection::Result->new(
    orchestrate  => $orchestrate,
    collection   => $self,
    key          => $key,
    ref          => $ref,
    data         => $data,
    etag         => $etag,
    column_names => \@columns,
  );

}

sub search {
  my $self = shift;

  my $orchestrate = $self->orchestrate;

  my $url = $self->url->clone;

  $url->query(query => shift);

  my $ua   = $orchestrate->ua;
  my $tx   = $ua->get($url);
  my $data = $tx->res->json;

  croak $data->{message} unless $tx->success;

  my @columns = keys %{$data->{results}->[0]->{value}};
  my $total   = $data->{total_count};

  return Orchestrate::Collection::ResultSet->new(
    orchestrate  => $orchestrate,
    collection   => $self,
    data         => $data,
    next_data    => $data,
    column_names => \@columns,
    total        => $total,
  );

}

# If key is supplied, create will only create if key does not exist
# $->create('ass', json => {}, ref => 'asdfadsf');
sub create {
  my $self = shift;

  my $orchestrate = $self->orchestrate;

  my $ua  = $orchestrate->ua;
  my $url = $self->url->clone;

  if ( $_[0] )
  my $tx;
  if (@_ > 1) {
    $url->path(shift);
    $tx = $ua->build_tx(
      PUT => $url => {'If-None-Match' => '"*"'} => json => shift);
  }
  elsif (@_) {
    $tx = $ua->build_tx(PUT => $url => json => shift);
    return;
  }
  else {
    return;
  }

  $tx = $ua->start($tx);

  croak $tx->res->json->{message} unless $tx->success;

  my $path = Mojo::Path->new($tx->res->headers->location);
  my ($key, $ref) = (@{$path->parts})[2, 4];

  return Orchestrate::Collection::Result->new(
    orchestrate => $orchestrate,
    collection  => $self,
    key         => $key,
    ref         => $ref,
    etag        => $tx->res->headers->etag,
  );

}

sub update_or_create {
  my $self = shift;

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->url->clone;

  $url->path(shift);

  my $tx = $ua->put(json => shift);

  if (@_) {
    $tx->req->headers->add('If-Match' => '"'.shift.'"');
  }

  $tx = $ua->start($tx);

  croak $tx->res->json->{message} unless $tx->success;

  my $path = Mojo::Path->new($tx->res->headers->location);
  my ($key, $ref) = (@{$path->parts})[2, 4];

  return Orchestrate::Collection::Result->new(
    orchestrate => $orchestrate,
    collection  => $self,
    key         => $key,
    ref         => $ref,
    etag        => $tx->res->headers->etag,
  );
}

sub delete {
  my ($self, $key, %opts) = @_;

  return unless $key;

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->url->clone;

  $url->path($key);

  $url->query(purge => 'true') if ( $opts{purge} );
  my $tx = $ua->build_tx(DELETE => $url);
  $tx->req->headers->add('If-Match' => '"'.$opts{ref}.'"') if $opts{ref};

  $tx = $ua->start($tx);

  croak $tx->res->json->{message} unless $tx->success;

  return $self;

}

sub list_refs {
  my ($self,$key,%opts) = @_;

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  return unless $key;


  $url->path($key.'/refs/');

  for ( keys %opts ) {
    $url->query({$_ => $opts{$_}});
  }


  my $ua   = $orchestrate->ua;
  my $tx   = $ua->get($url);
  my $data = $tx->res->json;

  croak $data->{message} unless $tx->success;

  my @columns = keys %{$data->{results}->[0]->{value}};
  my $total   = $data->{total_count};

  return Orchestrate::Collection::ResultSet->new(
    orchestrate  => $orchestrate,
    collection   => $self,
    data         => $data,
    next_data    => $data,
    column_names => \@columns,
    total        => $total,
  );
}

sub get_event {
  my ($self,$key,%opts) = @_;

  return unless $key;

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path($key.'/events/');

  for ( keys %opts ) {
    $url->query({$_ => $opts{$_}});
  }

  my $ua   = $orchestrate->ua;
  my $tx   = $ua->get($url);
  my $data = $tx->res->json;

  croak $data->{message} unless $tx->success;

  my @columns = keys %{$data->{results}->[0]->{value}};
  my $total   = $data->{total_count};

  return Orchestrate::Collection::Event->new(
    orchestrate  => $orchestrate,
    collection   => $self,
    data         => $data,
    next_data    => $data,
    column_names => \@columns,
    total        => $total,
  );
}

sub create_event {

}

sub update_event {

}

sub delete_event {

}

sub list_events {

}

sub get_related {
  my ($self,$key,%opts) = @_;

  return unless $key;
  return unless $opts{kinds} and ref $opts{kinds} eq 'ARRAY';

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

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
  my ($self,$key,%opts) = @_;

  return unless $key;
  return unless $opts{kind};
  return unless $opts{to_collection};
  return unless $opts{to_key};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path($key.'/relation/');
  $url->path($opts{kind}.'/'.$opts{to_collection}.'/'.$opts{to_key});

  say $url;
  my $ua   = $orchestrate->ua;
  my $tx   = $ua->put($url);

  croak $tx->res->json->{message} unless $tx->success;

  return;

}

sub delete_related {
  my ($self,$key,%opts) = @_;

  return unless $key;
  return unless $opts{kind};
  return unless $opts{to_collection};
  return unless $opts{to_key};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path($key.'/relation/');
  $url->path($opts{kind}.'/'.$opts{to_collection}.'/'.$opts{to_key});

  $url->query(purge => 'true') if $opts{purge};

  my $ua   = $orchestrate->ua;
  my $tx   = $ua->delete($url);

  croak $tx->res->json->{message} unless $tx->success;

  return;

}

# sub create_bulk {

# }

# sub update_bulk {

# }

1;

=encoding utf8

=head1 NAME

Orchestrate::Collection -

=head1 SYNOPSIS

  my $rs = $collection->search('Sa');