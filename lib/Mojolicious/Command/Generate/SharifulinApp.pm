package Mojolicious::Command::Generate::SharifulinApp;

use strict;
use warnings;

use base 'Mojo::Command';

__PACKAGE__->attr(description => <<'EOF');
Generate application directory structure (sharifulin style).
EOF
__PACKAGE__->attr(usage => <<"EOF");
usage: $0 generate app [NAME]
EOF

# Why can't she just drink herself happy like a normal person?
sub run {
    my ($self, $class) = @_;
    $class ||= 'App';

    my $name = $self->class_to_file($class);

    # Script
    $self->render_to_rel_file('mojo', "$name/script/$name", $class);
    $self->chmod_file("$name/script/$name", 0744);

    # Appclass
    my $app = $self->class_to_path($class);
    $self->render_to_rel_file('appclass', "$name/lib/$app", $class);

    # Base Controller
    my $basecontroller = "${class}::Controller";
    my $basepath       = $self->class_to_path($basecontroller);
    $self->render_to_rel_file('basecontroller', "$name/lib/$basepath", $basecontroller);
    
    # Controller
    my $controller = "${class}::Index";
    my $path       = $self->class_to_path($controller);
    $self->render_to_rel_file('controller', "$name/lib/$path", $controller);

    # Conf
    $self->render_to_rel_file('conf', "$name/conf/$name.conf", $name);

    # Conf Mysql
    $self->render_to_rel_file('confmysql', "$name/conf/mysql.conf", $name);

    # Bin
    $self->render_to_rel_file('binmysql', "$name/bin/mysql", $name);
    $self->chmod_file("$name/bin/mysql", 0744);
	
    $self->render_to_rel_file('binmysqldump', "$name/bin/mysqldump", $name);
    $self->chmod_file("$name/bin/mysqldump", 0744);
	
    $self->render_to_rel_file('bincheck', "$name/bin/check.sh", $name);
    $self->chmod_file("$name/bin/check.sh", 0744);
	
    $self->render_to_rel_file('binstop', "$name/bin/stop.sh", $name);
    $self->chmod_file("$name/bin/stop.sh", 0744);
	
    $self->render_to_rel_file('binstart', "$name/bin/start.sh", $name);
    $self->chmod_file("$name/bin/start.sh", 0744);
	
    $self->render_to_rel_file('binrestart', "$name/bin/restart.sh", $name);
    $self->chmod_file("$name/bin/restart.sh", 0744);
	
    $self->render_to_rel_file('binlogs', "$name/bin/logs.sh", $name);
    $self->chmod_file("$name/bin/logs.sh", 0744);
	
    # Test
    $self->render_to_rel_file('test', "$name/t/basic.t", $class);

    # Log
    $self->create_rel_dir("$name/log");
    
    # Tmp
    $self->create_rel_dir("$name/tmp");

    # Tmp Upload
    $self->create_rel_dir("$name/tmp/upload");
    
    # Static
    $self->render_to_rel_file('static', "$name/data/index.html");

    # Layout and Templates
    $self->renderer->line_start('%%');
    $self->renderer->tag_start('<%%');
    $self->renderer->tag_end('%%>');
    $self->render_to_rel_file('not_found',
        "$name/tmpl/not_found.html.ep");
    $self->render_to_rel_file('exception',
        "$name/tmpl/exception.html.ep");
    $self->render_to_rel_file('layout',
        "$name/tmpl/layouts/default.html.ep");
    $self->render_to_rel_file('welcome',
        "$name/tmpl/index/show.html.ep");
}

1;
__DATA__
@@ mojo
% my $class = shift;
#!/usr/bin/env perl
use common::sense;
use lib qw(lib /tk/lib /tk/mojo/lib);

BEGIN {
	# $ENV{MOJO_MODE} ||= 1;
	$ENV{MOJO_TMPDIR} = 'tmp/upload';
	$ENV{MOJO_MAX_MESSAGE_SIZE} = 50 * 1024 * 1024; # 50 MB
};

$ENV{MOJO_APP} ||= '<%= $class %>';

use Mojolicious::Commands; Mojolicious::Commands->start;

@@ appclass
% my $class = shift;
package <%= $class %>;
use common::sense;

use Util;
use base 'Mojolicious';

__PACKAGE__->attr(conf => sub { do 'conf/app.conf' });
__PACKAGE__->attr(db   => sub { $::DB ||= Util->db( do 'conf/mysql.conf' ) });

sub startup {
	my $self = shift;
	my $conf = $self->conf;
	
	$self->static  ->root($conf->{path}->{data});
	$self->renderer->root($conf->{path}->{tmpl});
	$self->log( Mojo::Log->new( %{$conf->{log}} ) ) if $conf->{log};
	
	$self->secret( $conf->{secret} ) if $conf->{secret};
	
	if ($conf->{session}) {
		$self->session->cookie_name( $conf->{session}->{name} );
		$self->session->cookie_domain( $conf->{session}->{domain} );
		$self->session->default_expiration( $conf->{session}->{expires} );
	}
	
	# plugins
	
	# $self->plugin('name' => {});
	
	# helpers
	
	$self->renderer->add_helper(conf      => sub { shift->app->conf->{+shift} });
	$self->renderer->add_helper(vu        => sub { shift->tx->req->url->path->parts->[+shift] || '' });
	$self->renderer->add_helper(is_iphone => sub { shift->tx->req->headers->user_agent =~ /iphone|ipad|cfnetwork/i ? 1 : 0 });
	
	# types
	
	$self->types->type(json => 'text/plain');
	
	# routes
	
	my $r = $self->routes;
	
	$r->route('/')->to('index#show');
	
	# my $a = $r->bridge('/admin')->to('admin#check');
	# 
	# $a->route('/')->to('admin-index#list');
}

1;

@@ basecontroller
% my $class = shift;
package <%= $class %>;
use common::sense;

use base 'Mojolicious::Controller';

package App::Controller;
use common::sense;

use base 'Mojolicious::Controller';

sub status {
	my $self = shift;
	
	$self->res->code(shift || 200);
	$self->rendered;
}

sub redirect {
	my $self = shift;
	
	$self->res->code(302);
	$self->res->headers->location( shift || $self->return_url );
	$self->rendered;
}

sub return_url {
	my $self = shift;
	my $referer = $self->req->headers->header('Referer');
	
	return $referer && $referer !~ /login|logout/ ? $referer : '/'; 
}

sub redirect_accel {
	my $self = shift;
	
	my $url  = shift || return;
	my $type = shift || '';
	
	for ($self->res->headers) {
		$_->content_type( $type );
		$_->header( 'X-Accel-Redirect' => $url );
	}
	
	$self->rendered;
}

1;

@@ controller
% my $class = shift;
package <%= $class %>;
use common::sense;

use base 'App::Controller';

sub show {
	my $self = shift;
	$self->render(message => 'Welcome to the Mojolicious Web Framework!');
}

1;

@@ conf
% my $name = shift;
{
	# secret => 'secret',
	# server => {
	# 	www => 'http://mojolicio.us',
	# },
	# session => {
	# 	name    => '<%= $name %>',
	# 	domain  => 'mojolicio.us',
	# 	expires => 60 * 60 * 24 * 30, # 1 month
	# },
	# sendmail => {
	# 	from => '<%= $name %>@mojolicio.us',
	# },
	path   => {
		data   => 'data',
		tmpl   => 'tmpl',
	},
	log    => {
		level => 'debug', # warn
		path  => 'log/<%= $name %>.log',
	},
	limit  => { },
};

@@ confmysql
% my $name = shift;
{
	'drivername'   => 'mysql',
	'user'         => '<%= $name %>',
	'password'     => '',
	'datasource'   => {
		'database' => '<%= $name %>',
		'host'     => 'localhost',
	},
};

@@ binmysql
#!/usr/bin/perl
use strict;
use lib qw(.. ../lib);
my $OPTIONS = join ' ',map {/\s/ ? "\"$_\"" : $_} @ARGV;
system qq(/usr/bin/mysql -u$_->{'user'} @{[ $_->{'password'} ? "-p$_->{'password'}" : '' ]} -h$_->{'datasource'}->{'host'} $OPTIONS $_->{'datasource'}->{'database'}) for require "conf/mysql.conf";

@@ binmysqldump
#!/usr/bin/perl
use strict;
use lib qw(.. ../lib);
my $OPTIONS = join ' ',grep {/^-/}  @ARGV;
my $TABLES  = join ' ',grep {!/^-/} @ARGV;
system qq(/usr/bin/mysqldump -u$_->{'user'} @{[ $_->{'password'} ? "-p$_->{'password'}" : '' ]} -h$_->{'datasource'}->{'host'} $OPTIONS $_->{'datasource'}->{'database'} $TABLES) for require "conf/mysql.conf";

@@ bincheck
% my $name = shift;
#!/bin/sh
ps auxww | grep -F 'script/<%= $name %>' | grep -Fv grep

@@ binstop
% my $name = shift;
#!/bin/sh
kill -9 `bin/check.sh | awk '{print $2}'`

@@ binstart
% my $name = shift;
#!/bin/bash
(
	script/<%= $name %> daemon --reload --listen http://127.0.0.1:3000 --pid tmp/<%= $name %>.pid 2>&1 # | while read F; do echo [`date`] $F; done
) >> log/<%= $name %>.error.log &

@@ binrestart
#!/bin/bash

bin/stop.sh
bin/start.sh

@@ binlogs
% my $name = shift;
tail -n 50 -f log/<%= $name %>.error.log log/<%= $name %>.log

@@ static
<!doctype html><html>
    <head><title>Welcome to the Mojolicious Web Framework!</title></head>
    <body>
        <h2>Welcome to the Mojolicious Web Framework!</h2>
        This is the static document "data/index.html",
        <a href="/">click here</a> to get back to the start.
    </body>
</html>

@@ test
% my $class = shift;
#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 5;
use Test::Mojo;

use_ok('<%= $class %>');

# Test
my $t = Test::Mojo->new(app => '<%= $class %>');
$t->get_ok('/')->status_is(200)->content_type_is('text/html')
  ->content_like(qr/Mojolicious Web Framework/i);
@@ not_found
<!doctype html><html>
    <head><title>Not Found</title></head>
    <body>
        The page you were requesting
        "<%= $self->req->url->path || '/' %>"
        could not be found.
    </body>
</html>
@@ exception
% my $e = delete $self->stash->{'exception'};
<!doctype html><html>
    <head>
	    <title>Exception</title>
	    <style type="text/css">
	        body {
		        font: 0.9em Verdana, "Bitstream Vera Sans", sans-serif;
	        }
	        .snippet {
                font: 115% Monaco, "Courier New", monospace;
	        }
	    </style>
    </head>
    <body>
        <% if ($self->app->mode eq 'development') { %>
	        <div>
                This page was generated from the template
                "tmpl/exception.html.ep".
            </div>
            <div class="snippet"><pre><%= $e->message %></pre></div>
            <div>
                <% for my $line (@{$e->lines_before}) { %>
                    <div class="snippet">
                        <%= $line->[0] %>: <%= $line->[1] %>
                    </div>
                <% } %>
                <% if ($e->line->[0]) { %>
                    <div class="snippet">
	                    <b><%= $e->line->[0] %>: <%= $e->line->[1] %></b>
	                </div>
                <% } %>
                <% for my $line (@{$e->lines_after}) { %>
                    <div class="snippet">
                        <%= $line->[0] %>: <%= $line->[1] %>
                    </div>
                <% } %>
            </div>
            <div class="snippet"><pre><%= dumper $self->stash %></pre></div>
        <% } else { %>
            <div>Page temporarily unavailable, please come back later.</div>
        <% } %>
    </body>
</html>
@@ layout
<!doctype html><html>
    <head><title>Welcome</title></head>
    <body><%== content %></body>
</html>
@@ welcome
% layout 'default';
<h2><%= $message %></h2>
This page was generated from the template
"tmpl/index/show.html.ep" and the layout
"tmpl/layouts/default.html.ep",
<a href="<%== url_for %>">click here</a>
to reload the page or
<a href="/index.html">here</a>
to move forward to a static page.
__END__
=head1 NAME

Mojolicious::Command::Generate::SharifulinApp - App Generator Command Sharifulin Style

=head1 SYNOPSIS
    
    # generate
    $ script/mojolicious generate sharifulin_app App
    
    # in code
    use Mojolicious::Command::Generate::SharifulinApp;

    my $app = Mojolicious::Command::Generate::SharifulinApp->new;
    $app->run(@ARGV);

=head1 DESCRIPTION

L<Mojolicious::Command::Generate::SharifulinApp> is a application generator (sharifulin style).

=head1 ATTRIBUTES

L<Mojolicious::Command::Generate::SharifulinApp> inherits all attributes from
L<Mojo::Command> and implements the following new ones.

=head2 C<description>

    my $description = $app->description;
    $app            = $app->description('Foo!');

Short description of this command, used for the command list.

=head2 C<usage>

    my $usage = $app->usage;
    $app      = $app->usage('Foo!');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Mojolicious::Command::Generate::App> inherits all methods from
L<Mojo::Command> and implements the following new ones.

=head2 C<run>

    $app->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut
