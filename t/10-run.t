#!/usr/bin/env perl

use strict;
use warnings;

use Capture::Tiny;
use Test::Exception;
use Test::Git;
use Test::More;

use App::GitHooks::Test qw( ok_add_files ok_setup_repository );


## no critic (RegularExpressions::RequireExtendedFormatting)

# List of tests to perform.
my $tests =
[
	# Make sure the plugin correctly analyzes Perl files.
	{
		name     => 'Fail interpreter check.',
		files    =>
		{
			'test.pl' => "#!perl\n\nuse strict;\n1;\n",
		},
		expected => qr/x The Perl interpreter line is correct/,
	},
	{
		name     => 'Pass interpreter check.',
		files    =>
		{
			'test.pl' => "#!/usr/bin/env perl\n\nuse strict;\n1;\n",
		},
		expected => qr/o The Perl interpreter line is correct/,
	},
	# Make sure the correct file times are analyzed.
	{
		name     => 'Skip non-Perl files',
		files    =>
		{
			'test.txt' => 'A text file.',
		},
		expected => qr/^(?!.*\Qx The Perl interpreter line is correct\E)/,
	},
	{
		name     => 'Catch .pm files.',
		files    =>
		{
			'test.pm' => "#!perl\n\nuse strict;\n1;\n",
		},
		expected => qr/x The Perl interpreter line is correct/,
	},
	{
		name     => 'Catch .pl files.',
		files    =>
		{
			'test.pl' => "#!perl\n\nuse strict;\n1;\n",
		},
		expected => qr/x The Perl interpreter line is correct/,
	},
	{
		name     => 'Catch .t files.',
		files    =>
		{
			'test.t' => "#!perl\n\nuse strict;\n1;\n",
		},
		expected => qr/x The Perl interpreter line is correct/,
	},
	{
		name     => 'Catch files without extension but with a Perl hashbang line.',
		files    =>
		{
			'test' => "#!perl\n\nuse strict;\n1;\n",
		},
		expected => qr/x The Perl interpreter line is correct/,
	},
	{
		name     => 'Skip files without extension and no hashbang.',
		files    =>
		{
			'test' => "A regular non-Perl file.\n",
		},
		expected => qr/^(?!.*\QThe Perl interpreter line is correct\E)/,
	},
];

# Bail out if Git isn't available.
has_git();
plan( tests => scalar( @$tests ) );

foreach my $test ( @$tests )
{
	subtest(
		$test->{'name'},
		sub
		{
			plan( tests => 4 );

			my $repository = ok_setup_repository(
				cleanup_test_repository => 1,
				config                  => '[PerlInterpreter]' . "\n"
					. 'interpreter_regex = /^#!\/usr\/bin\/env perl$/' . "\n",
				hooks                   => [ 'pre-commit' ],
				plugins                 => [ 'App::GitHooks::Plugin::PerlInterpreter' ],
			);

			# Set up test files.
			ok_add_files(
				files      => $test->{'files'},
				repository => $repository,
			);

			# Try to commit.
			my $stderr;
			lives_ok(
				sub
				{
					$stderr = Capture::Tiny::capture_stderr(
						sub
						{
							$repository->run( 'commit', '-m', 'Test message.' );
						}
					);
					note( $stderr );
				},
				'Commit the changes.',
			);

			like(
				$stderr,
				$test->{'expected'},
				"The output matches expected results.",
			);
		}
	);
}
