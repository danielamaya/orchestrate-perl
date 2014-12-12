package Orchestrate::Collection;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;
use Mojo::JSON qw(encode_json);
use Orchestrate::Collection::ResultSet;

has [qw(orchestrate name)];

sub create_collection {
  my ($self, $key, $data) = @_;
  my $orchestrate = $self->orchestrate;

  my $ua  = $orchestrate->ua;
  my $url = Mojo::URL->new($orchestrate->base_url)->userinfo($orchestrate->secret);

  $url->path($self->name.'/'.$key);

  my $tx = $ua->put($url =>
    { 'Content-Type' => 'application/json' } =>
    json => $data
  );

  print $tx->res->code;

}

sub delete_collection {
  my $self = shift;
  my $orchestrate = $self->orchestrate;

  my $ua = $orchestrate->ua;
  my $url = Mojo::URL->new($orchestrate->base_url)->userinfo($orchestrate->secret);

  $url->path($self->name);
  $url->query(force => 'true');

  return $ua->delete($url);

}

sub find {
  my ($self, $key, $ref) = @_;

  my $orchestrate = $self->orchestrate;
  my $ua = $orchestrate->ua;
  my $url = $orchestrate->secret_url->clone;

  if ( $ref ) {
    $url->path($self->name.'/'.$key.'/ref/'.$ref);
  }
  else {
    $url->path($self->name.'/'.$key);
  }
  my $tx = $ua->get($url);

  my $data = $tx->res->json;
  my ($res_key,$res_ref) = (split('/',$tx->res->headers->content_location))[3,5];
  my $etag = $tx->res->headers->etag;

  return Orchestrate::Collection::Result->new(
    orchestrate => $orchestrate,
    collection => $self,
    key => $res_key,
    ref => $res_ref,
    data => $data,
    etag => $etag,
  );

}

sub search {
  my ($self, $args) = @_;
  my $orchestrate = $self->orchestrate;

  my $ua = $orchestrate->ua;
  my $url = Mojo::URL->new($orchestrate->base_url)->userinfo($orchestrate->secret);

  $url->path($self->name);
  $url->query(query => $args);

  my $data = $ua->get($url)->res->json;
  my @columns = keys %{ $data->{results}->[0]->{value} };
  my $total = $data->{total_count};
  my $next = $data->{next};
  return Orchestrate::Collection::ResultSet->new(orchestrate => $orchestrate, collection => $self, data => $data->{results}, column_names => \@columns, total => $total, next_url => $next);
}

sub create {
  my ($self, $key, $data, $ref) = @_;
  my $orchestrate = $self->orchestrate;

  my $ua  = $orchestrate->ua;
  my $url = Mojo::URL->new($orchestrate->base_url)->userinfo($orchestrate->secret);


  my $method;
  if ( ref $key and !$data ) {
    $method = 'post';
    $data = $key;
    $url->path($self->name);
  }
  elsif ( ref $data ) {
    $method = 'put';
    $url->path($self->name.'/'.$key);
  }

  my $tx = $ua->build_tx($method => $url => { 'Content-Type' => 'application/json' }, json => $data);

  if ( $ref and $ref eq 'false' and $method eq 'put' ) {
    $tx->req->headers->add('If-None-Match' => '*');
  }
  elsif ( $ref and $method eq 'put' ) {
    $tx->req->headers->add('If-Match' => "\"$ref\"");
  }

  $tx = $ua->start($tx);

  my ($res_key,$res_ref) = (split('/',$tx->res->headers->location))[3,5];

  return Orchestrate::Collection::Relationship->new(orchestrate => $orchestrate, collection => $self, key => $res_key, ref => $res_ref);

}

sub delete {
  my ($self, $key, $purge, $ref) = (shift, shift, shift, shift);
  my $orchestrate = $self->orchestrate;

  my $ua = $orchestrate->ua;
  my $url = Mojo::URL->new($orchestrate->base_url)->userinfo($orchestrate->secret);

  $url->path($self->name.'/'.$key);
  $url->query(purge => 'true') if $purge;


  return $ua->delete($url);

}

1;
