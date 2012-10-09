use strict;
use warnings;
use Test::More;

plan skip_all => 'VMS only test' unless $^O eq 'VMS';
plan tests => 2;

is eval { Shell::Guess->running_shell->is_dcl }, 1, "running dcl";
is eval { Shell::Guess->login_shell->is_dcl }, 1, "login dcl";