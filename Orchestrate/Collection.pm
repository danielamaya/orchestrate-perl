package Orchestrate::Collection;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;
use Mojo::JSON qw(encode_json);
use Orchestrate::Collection::ResultSet;
use Orchestrate::Collection::Result;

has [qw(orchestrate name url)];

sub find {
    my ( $self, $key, $ref ) = @_;

    my $orchestrate = $self->orchestrate;
    my $ua          = $orchestrate->ua;
    my $url = $self->url->clone;
    $ref ? push @{$url->path}, "$key/ref/$ref" : push @{$url->path}, $key;


    my $tx = $ua->get($url);
    my $data = $tx->res->json;

    return if $data->{code} and $orchestrate->_error($data->{code});
    my $res_path = Mojo::Path->new( $tx->res->headers->content_location );
    my $res_ref  = @{ $res_path->parts }[-1];


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
    my ( $self, $args ) = @_;
    my $orchestrate = $self->orchestrate;


    my $url = $self->url->clone;
    $url->path( $self->name );
    $url->query( query => $args );

    my $ua   = $orchestrate->ua;
    my $data = $ua->get($url)->res->json;

    my @columns = keys %{ $data->{results}->[0]->{value} };
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
# If key is supplied, create will only create if key does not exist

sub create {
  my ( $self, $key, $data ) = @_;
  my $orchestrate = $self->orchestrate;

  my $ua  = $orchestrate->ua;
  my $url = $self->url->clone;

  my $method;
  if (ref $key and !$data) {
    $method = 'post';
    $data = $key;
  }
  elsif ( $key and ref $data ) {
    $method = 'put';
    croak qq{$key already exists in collection} if $self->find($key);
    push @{$url->path}, $key;
  }
  else {
    return;
  }

  my $tx  = $ua->build_tx(
    $method => $url => { 'Content-Type' => 'application/json' } => json => $data
  );

  $tx = $ua->start($tx);

  say $tx->res->headers->to_string;
  my $res_path = Mojo::Path->new( $tx->res->headers->location );
  my ( $res_key, $res_ref ) = ( @{ $res_path->parts } )[ 2, 4 ];

  return Orchestrate::Collection::Relationship->new(
      orchestrate => $orchestrate,
      collection  => $self,
      key         => $res_key,
      ref         => $res_ref
  );

}

sub update {
  my ($self, $key, $data, $ref) = @_;

  my $orchestrate = $self->orchestrate;
  my $ua  = $orchestrate->ua;
  my $url = $self->url->clone;

  push @{$url->path}, $key;

  my $tx = $ua->build_tx(
    PUT => $url => {'Content-Type' => 'application/json'} => json => $data
  );

  if ($ref and $ref eq 'false' ) {
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

sub find_or_create {

}

sub update_or_create {

}

sub create_all {

}
sub update_all {

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

    sub get_related {

}

sub create_related {

}

sub delete_related {

}

sub get_refs {
  my ($self,%opts) =  shift;

  croak qq{Key required.} unless ($opts{key});

}

1;
