
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

## TODO

1. Allow the ability to specify ref to find method.
1. Create the following methods:
  * list_refs
  * list
  * prev/next to iterrate over a resultset
  * related methods
  * event methods
1. Get should return a resultset object.
1. Resultset objects should have relation methods.

## Installation

  When this is on CPAN all you will need is a oneliner:

    $ curl -L cpanmin.us | perl - -n Orchestrate

  Recommend the use of a [Perlbrew](http://perlbrew.pl) environment.

