package PLN::PT::app;
use Dancer2;
use Dancer2::Plugin::Locale::Wolowitz;

use File::Temp qw/tempdir/;;
use Path::Tiny;
use Cwd;
use JSON::XS;
use LWP::UserAgent;
use utf8::all;
use Encode;
use Tree::Simple;
use Tree::Simple::View::ASCII;

our $VERSION = '0.1';

hook 'before' => sub {
  my $l = session 'lang';
  unless ($l) {
    session 'lang' => 'pt';
  }
};

get '/lang/:l' => sub {
  my $l = param 'l';
  if ($l) { session 'lang' => $l; }
  redirect request->referer;
};

get '/' => sub {
  template 'index' => { index=>1 };
};

get '/resources' => sub {
  template 'resources';
};

get '/api' => sub {
  template 'api' => { api => 1 };
};

get '/online' => sub {
  template 'online' => { online => 1 };
};

post '/online' => sub {
  my $text = param 'text';
  redirect '/online' unless $text;

  my $process = param 'process';
  my ($json, $raw);

  my $opts = { output => 'rawjson' };

  if ($process) {
    my $url = "http://api.pln.pt/$process";

    my $output = _do_post($url, $text, $opts);
    my $data = JSON::XS->new->decode($output);

    $raw = $data->{raw};
    $json = JSON::XS->new->encode($data->{json});
  }

  my ($parse_tree, $ascii_tree);
  if (lc($process) eq 'dep_parser') {
    $ascii_tree = _build_ascii_tree(JSON::XS->new->decode($json));
  }

  my $actants;
  if (lc($process) eq 'actants') {
    $actants = JSON::XS->new->decode($json);
  }

  template 'online' => {
      online => 1,
      text   => $text,
      json   => $json,
      raw    => $raw,
      myproc => $process,
      parse_tree => $parse_tree,
      ascii_tree => $ascii_tree,
      actants => $actants
    };
};

sub _do_post {
  my ($url, $text, $opts) = @_;

  # handle options
  my @opts;
  foreach (keys %$opts) {
    push @opts, "$_=$opts->{$_}";
  }
  $url = $url . "?" . join('&', @opts);

  my $i = File::Temp->new;
  my $input = $i->filename;
  path($input)->spew_utf8($text);
  my $r = `curl -s -X POST -d \@$input $url`;

  return $r;
}

sub _build_ascii_tree {
  my ($data) = @_;
  my $tree;

  for (@$data) {
    if ($_->[7] eq 'ROOT') {
      $tree = Tree::Simple->new(_tree_build_str($_), Tree::Simple->ROOT);
      _tree_add_child($_, $tree, $data);
    }
  }

  my $tree_view = Tree::Simple::View::ASCII->new($tree);
  $tree_view->includeTrunk(1);
  return $tree_view->expandAll();
}

sub _tree_build_str {
  my ($token) = @_;
  my $str = join(' ', $token->[1], $token->[3], $token->[7]);
  return $str;
}

sub _tree_add_child {
  my ($token, $tree, $data) = @_;

  for (@$data) {
    if ($_->[6] eq $token->[0]) {
      my $t = Tree::Simple->new(_tree_build_str($_), $tree);
      _tree_add_child($_, $t, $data);
    }
  }

  return $tree;
}

true;

