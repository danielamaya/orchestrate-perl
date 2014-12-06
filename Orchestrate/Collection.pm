package Orchestrate::Collection;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;
use Mojo::JSON qw(encode_json);

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
  my ($self, $key) = (shift, shift);
  my $orchestrate = $self->orchestrate;

  my $ua = $orchestrate->ua;
  my $url = Mojo::URL->new($orchestrate->base_url)->userinfo($orchestrate->secret);

  $url->path($self->name.'/'.$key);

  return $ua->get($url)->res->json;

}

sub search {
  my ($self, $args) = @_;
  my $orchestrate = $self->orchestrate;

  my $ua = $orchestrate->ua;
  my $url = Mojo::URL->new($orchestrate->base_url)->userinfo($orchestrate->secret);

  $url->path($self->name);
  $url->query($args);

  return $ua->get($url)->res->json;
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

  if ( $ref and $ref eq 'false' ) {
    $tx->res->headers->add('If-None-Match' => '*');
  }
  elsif ( $ref ) {
    $tx->res->headers->add('If-Match' => "\"$ref\"");
  }

  $tx = $ua->start($tx);

  print $tx->res->code;

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