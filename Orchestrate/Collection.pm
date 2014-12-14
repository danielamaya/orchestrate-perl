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
  my ($self,%opts) = @_;

  return unless $opts{data};

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->url->clone;

  my $tx;
  if ( $opts{key} ) {
    $url->path($opts{key});
    $tx = $ua->build_tx(PUT => $url => json => $opts{data});
    $tx->req->headers->if_none_match('"*"');
  }
  else {
    $tx = $ua->build_tx(POST => $url => json => $opts{data});
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
  my ($self,%opts) = @_;

  return unless $opts{data};
  return unless $opts{key};

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->url->clone;


  $url->path($opts{key});
  my $tx = $ua->build_tx(PUT => $url => json => $opts{data});

  $tx->req->headers->add('If-Match' => '"'.$opts{ref}.'"') if $opts{ref};

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
  my ($self,%opts) = @_;

  return unless $opts{key};

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->url->clone;

  $url->path($opts{key});

  $url->query(purge => 'true') if ( $opts{purge} );
  my $tx = $ua->build_tx(DELETE => $url);
  $tx->req->headers->add('If-Match' => '"'.$opts{ref}.'"') if $opts{ref};

  $tx = $ua->start($tx);

  croak $tx->res->json->{message} unless $tx->success;

  return $self;

}

sub list_refs {
  my ($self,%opts) = @_;

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  return unless $opts{key};


  $url->path(delete($opts{key}).'/refs/');

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
  my ($self,%opts) = @_;

  return unless $opts{key};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path(delete($opts{key}).'/events/');

  for ( keys %opts ) {
    $url->query({$_ => $opts{$_}});
  }

  my $ua   = $orchestrate->ua;
  my $tx   = $ua->get($url);
  my $data = $tx->res->json;

  croak $data->{message} unless $tx->success;

  my @columns = keys %{$data->{results}->[0]->{value}};
  my $total   = $data->{total_count};

  return Orchestrate::Collection::Result->new(
    orchestrate  => $orchestrate,
    collection   => $self,
    key          => $data->{path}->{key},
    ref          => $data->{path}->{ref},
    type         => $data->{path}->{type},
    data         => $data,
    etag         => $tx->res->headers->etag,
    timestamp    => $data->{timestamp},
    ordinal      => $data->{ordinal},
    column_names => \@columns,
  );

}

# POST /v0/$collection/$key/events/$type/$timestamp
sub create_event {
  my ($self,%opts) = @_;

  return unless $opts{key};
  return unless $opts{type};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path($opts{key}.'/events/'.$opts{type}.'/');
  $url->path($opts{timestamp}) if $opts{timestamp};

  my $ua   = $orchestrate->ua;
  my $tx   = $ua->post($url);

  croak $tx->res->json->{message} unless $tx->success;

  #Location: /v0/collection/key/events/type/1398286914202/9

  my $path = Mojo::Path->new($tx->res->headers->location);
  my ($key, $type, $timestamp, $ordinal) = (@{$path->parts})[2, 4, 5, 6];
  my $etag = $tx->res-headers->etag;
  (my $ref = $etag) =~ s/"//g;

  return Orchestrate::Collection::Result->new(
    orchestrate => $orchestrate,
    collection  => $self,
    key         => $key,
    type        => $type,
    timestamp   => $timestamp,
    ordinal     => $ordinal,
    ref         => $ref,
    etag        => $tx->res->headers->etag,
  );

}

# PUT /v0/$collection/$key/events/$type/$timestamp/$ordinal
sub update_event {
  my ($self,%opts) = @_;

  return unless $opts{key};
  return unless $opts{type};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path($opts{key}.'/events/'.$opts{type}.'/');
  $url->path($opts{timestamp}.'/') if $opts{timestamp};
  $url->path($opts{ordinal}) if $opts{ordinal};
  $url->path->trailing_slash(0);

  my $ua   = $orchestrate->ua;
  my $tx = $ua->build_tx(PUT => $url);
  $tx->req->headers->add('If-Match' => '"'.$opts{ref}.'"') if $opts{ref};
  $tx = $ua->start($tx);

  croak $tx->res->json->{message} unless $tx->success;

  my $path = Mojo::Path->new($tx->res->headers->location);
  my ($key, $type, $timestamp, $ordinal) = (@{$path->parts})[2, 4, 5, 6];
  my $etag = $tx->res-headers->etag;
  (my $ref = $etag) =~ s/"//g;

  return Orchestrate::Collection::Result->new(
    orchestrate => $orchestrate,
    collection  => $self,
    key         => $key,
    type        => $type,
    timestamp   => $timestamp,
    ordinal     => $ordinal,
    ref         => $ref,
    etag        => $tx->res->headers->etag,
  );

}

sub delete_event {
  my ($self,%opts) = @_;

  return unless $opts{key};
  return unless $opts{type};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path($opts{key}.'/events/'.$opts{type}.'/');
  $url->path($opts{timestamp}.'/') if $opts{timestamp};
  $url->path($opts{ordinal}) if $opts{ordinal};
  $url->path->trailing_slash(0);
  $url->query(purge => 'true') if $opts{purge};

  my $ua   = $orchestrate->ua;
  my $tx = $ua->build_tx(DEL => $url);
  $tx->req->headers->add('If-Match' => '"'.$opts{ref}.'"') if $opts{ref};
  $tx = $ua->start($tx);

  croak $tx->res->json->{message} unless $tx->success;
  return;
}

# GET /v0/$collection/$key/events/$type?startEvent=$startEvent&endEvent=$endEvent
sub list_events {
  my ($self,%opts) = @_;

  return unless $opts{key};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path($opts{key}.'/events/'.$opts{type});

  $url->query({startEvent => $opts{start_event}}) if $opts{start_event};
  $url->query({endEvent => $opts{end_event}}) if $opts{end_event};
  $url->query({beforeEvent => $opts{before_event}}) if $opts{before_event};
  $url->query({afterEvent => $opts{after_event}}) if $opts{after_event};
  $url->query({limit => $opts{limit}}) if $opts{limit};

  my $ua   = $orchestrate->ua;
  my $tx   = $ua->get($url);
  my $data = $tx->res->json;

  croak $data->{message} unless $tx->success;

  my @columns = keys %{$data->{results}->[0]->{value}};
  my $total   = $data->{total_count};

}

sub get_related {
  my ($self,%opts) = @_;

  return unless $opts{key};
  return unless $opts{kinds} and ref $opts{kinds} eq 'ARRAY';

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path(delete($opts{key}).'/relations/');

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

  return unless $opts{key};
  return unless $opts{kind};
  return unless $opts{to_collection};
  return unless $opts{to_key};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path(
    $opts{key}.'/relation/'.
    $opts{kind}.'/'.
    $opts{to_collection}.'/'.
    $opts{to_key}
  );

  say $url;
  my $ua   = $orchestrate->ua;
  my $tx   = $ua->put($url);

  croak $tx->res->json->{message} unless $tx->success;

  return;

}

sub delete_related {
  my ($self,%opts) = @_;

  return unless $opts{key};
  return unless $opts{kind};
  return unless $opts{to_collection};
  return unless $opts{to_key};

  my $orchestrate = $self->orchestrate;
  my $url         = $self->url->clone;

  $url->path(
    $opts{key}.'/relation/'.
    $opts{kind}.'/'.
    $opts{to_collection}.'/'.
    $opts{to_key}
  );

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