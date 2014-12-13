package Orchestrate::Collection::ResultSet;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;

has [qw(orchestrate data column_names next_url total)];

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

# sub next {
#   my $self = shift;
#   my $orchestrate = $self->orchestrate;

#   my $data = shift @{ $self->data };

#   if ( $data ) {
#     push @{$self->{prev_data}}, $data;

#     return Orchestrate::Collection::Result->new(
#         orchestrate  => $orchestrate,
#         collection   => $self,
#         key          => $key,
#         ref          => $res_ref,
#         data         => $data,
#         etag         => $etag,
#         column_names => \@columns,
#     );
#     return $data;
#   }
#   elsif ( !$data and $self->next_url ) {
#     my $url = Mojo::URL->new($self->next_url)->to_abs($orchestrate->secret_url)->fragment(undef);
#     $data = $orchestrate->ua->get($url)->res->json;

#     my $ret = shift @{ $data->{results} };
#     push @{$self->{prev_data}}, $ret;
#     $self->data($data->{results});
#     $data->{next} ? $self->next_url($data->{next}) : $self->next_url('');
#     return $ret;
#   }
#   else {
#     @{ $self->{prev_data} } = reverse @{ $self->{prev_data} };
#     return;
#   }

# }

sub prev {
  ref $_[0]->{prev_data} ? return pop @{ $_[0]->{prev_data} } : return;
}


sub columns {
  return @{ $_[0]->column_names };
}
1;
