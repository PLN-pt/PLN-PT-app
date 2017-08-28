#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use PLN::PT::app;
PLN::PT::app->to_app;
