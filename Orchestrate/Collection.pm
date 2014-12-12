package Orchestrate::Collection;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;
use Mojo::JSON qw(encode_json);
use Orchestrate::Collection::ResultSet;
use Orchestrate::Collection::Result;

has [qw(orchestrate name url)];

sub find {
  my ($self, $key, $ref) = @_;

  my $orchestrate = $self->orchestrate;
  my $ua          = $orchestrate->ua;
  my $url         = $self->url->clone->path($ref ? "$key/ref/$ref" : $key);

  my $tx = $ua->get($url);

  my $res_path = Mojo::Path->new($tx->res->headers->content_location);
  my $res_ref  = @{$res_path->parts}[-1];

  my $data    = $tx->res->json;
  my @columns = keys %{$data};
  my $etag    = $tx->res->headers->etag;

  return Orchestrate::Collection::Result->new(
    orchestrate  => $orchestrate,
    collection   => $self,
    key          => $key,
    ref          => $res_ref,
    data         => $data,
    etag         => $etag,
    column_names => \@columns,
  );

}

sub search {
  my ($self, $args) = @_;
  my $orchestrate = $self->orchestrate;


  my $url = $self->url->clone;
  $url->path($self->name);
  $url->query(query => $args);

  my $ua = $orchestrate->ua;
  my $data    = $ua->get($url)->res->json;

  my @columns = keys %{$data->{results}->[0]->{value}};
  my $total   = $data->{total_count};
  my $next    = $data->{next};

  return Orchestrate::Collection::ResultSet->new(
    orchestrate  => $orchestrate,
    collection   => $self,
    data         => $data->{results},
    column_names => \@columns,
    total        => $total,
    next_url     => $next
  );

}

# Returns a head that looks like:
# HTTP/1.1 201 Created
# Content-Type: application/json
# Date: Mon, 16 Jun 2014 17:57:07 GMT
# ETag: "82eafab14dc84ed3"
# Location: /v0/collection/035ab997adffe604/refs/82eafab14dc84ed3
# X-ORCHESTRATE-REQ-ID: a1feaa00-f57f-11e3-a294-0e490195c851
# transfer-encoding: chunked
# Connection: keep-alive

sub create {
  my ($self, $data) = @_;

  # my $orchestrate = $self->orchestrate;

  # my $ua  = $orchestrate->ua;
  # my $url = $self->url->clone;
  # my $tx = $ua->post($url => {'Content-Type' => 'application/json'} => json => $data);

  # return Orchestrate::Collection::Relationship->new(
  #   orchestrate => $orchestrate,
  #   collection  => $self,
  #   key         => $res_key,
  #   ref         => $res_ref
  # );

}

# sub update_or_create {
#   my ($self, $key, $data, $ref) = @_;
#   my $orchestrate = $self->orchestrate;

#   my $ua  = $orchestrate->ua;
#   my $url = $self->url->clone;

#   my $method = 'post';

#   if (ref $data) {
#     $method = 'put';
#     $url->path($key);
#   }

#   my $tx = $ua->build_tx(
#     $method => $url => {'Content-Type' => 'application/json'},
#     json    => $data
#   );

#   $ref ?
#   if ($ref and $ref eq 'false' and $method eq 'put') {
#     $tx->req->headers->add('If-None-Match' => '*');
#   }
#   elsif ($ref and $method eq 'put') {
#     $tx->req->headers->add('If-Match' => "\"$ref\"");
#   }

#   $tx = $ua->start($tx);

#   my ($res_key, $res_ref) = (split('/', $tx->res->headers->location))[3, 5];

#   return Orchestrate::Collection::Relationship->new(
#     orchestrate => $orchestrate,
#     collection  => $self,
#     key         => $res_key,
#     ref         => $res_ref
#   );

# }

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

sub get_related {

}

sub create_related {

}

sub delete_related {

}
1;
