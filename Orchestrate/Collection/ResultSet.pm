package Orchestrate::Collection::ResultSet;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;

has [qw(orchestrate collection data column_names next_url total prev_url)];

sub all {
  my $self = shift;
  my $orchestrate = $self->orchestrate;

  my $data = $self->data;

  my $res = $data->{results};

  return $res if !$data->{next};

  my $ua = $orchestrate->ua;

  while ( $data->{next} ) {
    my $url = Mojo::URL->new($data->{next})->to_abs($orchestrate->secret_url)->fragment(undef);
    $data = $ua->get($url)->res->json;
    push @{$res}, @{$data->{results}};
  }

  return $res;
}

sub next {
  my $self = shift;

  my $orchestrate = $self->orchestrate;
  my $data = shift @{ $self->data };

  if ( $data ) {
    return $data;
  }
  elsif ( !$data and $self->next_url ) {
    my $url = Mojo::URL->new($self->next_url)->to_abs($orchestrate->secret_url)->fragment(undef);
    $data = $orchestrate->ua->get($url)->res->json;

    my $ret = shift @{ $data->{results} };
    $self->data($data->{results});
    $data->{prev} ? $self->prev_url($data->{prev}) : $self->prev_url('');
    $data->{next} ? $self->next_url($data->{next}) : $self->next_url('');
    return $ret;
  }
  else {
    return;
  }

}

sub prev {
  my $self = shift;

  my $orchestrate = $self->orchestrate;
  my $data = shift @{ $self->data };

  if ( $data ) {
    return $data;
  }
  elsif ( !$data and $self->prev_url ) {
    my $url = Mojo::URL->new($self->prev_url)->to_abs($orchestrate->secret_url)->fragment(undef);
    $data = $orchestrate->ua->get($url)->res->json;

    my $ret = shift @{ $data->{results} };
    $self->data($data->{results});
    $data->{prev} ? $self->prev_url($data->{prev}) : $self->prev_url('');
    $data->{next} ? $self->next_url($data->{next}) : $self->next_url('');
    return $ret;
  }
  else {
    return;
  }

}


sub columns {
  my $self = shift;

  my @columns = @{$self->column_names};
  return @columns;
}
1;