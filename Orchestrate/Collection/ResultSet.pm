package Orchestrate::Collection::ResultSet;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;

has [qw(orchestrate collection data column_names next_data total)];

sub all {
  my $self        = shift;
  my $orchestrate = $self->orchestrate;

  if ($self->{prev_data} and scalar @{$self->{prev_data}} == $self->total) {
    return $self->{prev_data};
  }

  my $data = $self->data;

  my $res = $data->{results};

  return $res if !$data->{next};

  my $ua = $orchestrate->ua;

  while ($data->{next}) {
    my $url = Mojo::URL->new($data->{next})->to_abs($orchestrate->secret_url)
      ->fragment(undef);
    $data = $ua->get($url)->res->json;
    push @{$res}, @{$data->{results}};
  }

  return $res;
}

sub next {
  my $self        = shift;
  my $orchestrate = $self->orchestrate;

  my $data = $self->next_data;

  my $res = shift @{$data->{results}};

  if ($res) {
    push @{$self->{prev_data}}, $res;

    my @columns = keys %{$res};

    return Orchestrate::Collection::Result->new(
      orchestrate  => $orchestrate,
      collection   => $self,
      key          => $res->{path}->{key},
      ref          => $res->{path}->{ref},
      data         => $res->{value},
      column_names => \@columns,
    );

  }

  elsif (!$res and $self->next_data->{next}) {
    my $url = Mojo::URL->new($self->next_data->{next})
      ->to_abs($orchestrate->secret_url)->fragment(undef);

    $data = $orchestrate->ua->get($url)->res->json;
    my $res = shift @{$data->{results}};
    push @{$self->{prev_data}}, $res;
    $self->next_data($data);
    my @columns = keys %{$data};
    return Orchestrate::Collection::Result->new(
      orchestrate  => $orchestrate,
      collection   => $self,
      key          => $res->{path}->{key},
      ref          => $res->{path}->{ref},
      data         => $res->{value},
      column_names => \@columns,
    );
  }
  else {
    return;
  }
}

sub prev {
  my $self = shift;

  my $orchestrate = $self->orchestrate;
  my $res         = pop @{$self->{prev_data}};
  if ($res) {
    my @columns = keys %{$res};

    return Orchestrate::Collection::Result->new(
      orchestrate  => $orchestrate,
      collection   => $self,
      key          => $res->{path}->{key},
      ref          => $res->{path}->{ref},
      data         => $res->{value},
      column_names => \@columns,
    );
  }
  else {
    return;
  }
}

sub columns {
  return @{$_[0]->column_names};
}

1;
