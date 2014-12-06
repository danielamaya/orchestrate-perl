
  Pure-Perl non-blocking I/O Orchestrate client, optimized for use with the
  [Mojolicious](http://mojolicio.us) real-time web framework.

```perl
use Mojolicious::Lite;
use Orchestrate;

helper Orchestrate => sub { state $orchestrate = Orchestrate->new(secret => 'apikey') };

# Store and retrieve information non-blocking
get '/' => sub {
  my $c = shift;

  my $collection = $c->orchestrate->collection('games');

  $c->render(json => $collection->find('key', 'Game of War'));
};

app->start;
```

## Installation

  All you need is a oneliner, it takes less than a minute.

    $ curl -L cpanmin.us | perl - -n Orchestrate

  We recommend the use of a [Perlbrew](http://perlbrew.pl) environment.

