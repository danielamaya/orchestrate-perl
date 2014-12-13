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
    push @{$url->path}, shift . '/ref/' . shift;
  }
  elsif (@_) {
    push @{$url->path}, shift;
  }
  else {
    return;
  }
  my $tx   = $ua->get($url);
  my $data = $tx->res->json;

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
  $url->path($self->name);
  $url->query(query => shift);

  my $ua   = $orchestrate->ua;
  my $data = $ua->get($url)->res->json;

  $self->error('The requested items could not be found.') and return $self
    if $data->{count} == 0;


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

sub create {
  my $self = shift;

  my $orchestrate = $self->orchestrate;

  my $ua  = $orchestrate->ua;
  my $url = $self->url->clone;

  my $tx;
  if (@_ > 1) {
    push @{$url->path}, shift;
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

  croak 'Could not create record: ' . $tx->res->json->{message}
    unless $tx->success;

  my $res_path = Mojo::Path->new($tx->res->headers->location);
  my ($res_key, $res_ref) = (@{$res_path->parts})[2, 4];

  return Orchestrate::Collection::Result->new(
    orchestrate => $orchestrate,
    collection  => $self,
    key         => $res_key,
    ref         => $res_ref,
    etag        => $tx->res->headers->etag,
  );

}

sub update {
  my ($self, $key, $data, $ref) = @_;

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->url->clone;

  push @{$url->path}, $key;

  my $tx = $ua->build_tx(
    PUT => $url => {'Content-Type' => 'application/json'} => json => $data);

  if ($ref and $ref eq 'false') {
    $tx->req->headers->add('If-None-Match' => '*');
  }
  elsif ($ref) {
    $tx->req->headers->add('If-Match' => "\"$ref\"");
  }

  $tx = $ua->start($tx);

  say $tx->res->headers->to_string;

  # my ($res_key, $res_ref) = (split('/', $tx->res->headers->location))[3, 5];

  # return Orchestrate::Collection::Relationship->new(
  #   orchestrate => $orchestrate,
  #   collection  => $self,
  #   key         => $res_key,
  #   ref         => $res_ref
  # );

}

# sub delete {
#   my ($self, $key, $purge, $ref) = (shift, shift, shift, shift);
#   my $orchestrate = $self->orchestrate;

#   my $ua = $orchestrate->ua;
#   my $url
#     = Mojo::URL->new($orchestrate->base_url)->userinfo($orchestrate->secret);

#   $url->path($self->name . '/' . $key);
#   $url->query(purge => 'true') if $purge;


#   return $ua->delete($url);

# }

sub get_event {

}

sub create_event {

}

sub update_event {

}

sub delete_event {

}

sub find_or_create {

}

sub update_or_create {

}

sub create_all {

}

sub update_all {

}

sub get_related {

}

sub create_related {

}

sub delete_related {

}

sub get_refs {
  my ($self, %opts) = shift;

  croak qq{Key required.} unless ($opts{key});

}

1;
