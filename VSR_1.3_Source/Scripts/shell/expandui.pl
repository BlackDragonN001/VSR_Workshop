#!/usr/bin/perl

use POSIX;

############################## Start Script ###################################

$numArgs = $#ARGV + 1;

if($numArgs < 3)
{
	print STDERR "Expected expandui.pl scaleNumberX scaleNumberY fileNameModifier <input.cfg >output.cfg\n";
	print STDERR " e.g.   expandui.pl 2 2 _x2_0 <bzgame_command.cfg >bzgame_command_x2_0.cfg\n";
	exit(1);
}

my $xScaleMultiplier = $ARGV[0];
my $yScaleMultiplier = $ARGV[1];

my $filenameModifier = $ARGV[2];

# Read from standard input
my $line;
while($line = <STDIN>)
{
	$line =~ s/\n//;
	$line =~ s/\r//;
	chomp($line);

	# Handle various types of lines

	if(($line =~ /^\s*BorderSize\(/i) || 
	   ($line =~ /^\s*BevelSize\(/i) || 
	   ($line =~ /^\s*SliderPadding\(/i))
	{
		# Has 1 parameter, needing upscaling
		my $indexopen = index($line, "(");
		my $indexclose = index($line, ")");
		if(($indexopen == -1) || ($indexclose == -1) || ($indexclose < $indexopen))
		{
			# Doesn't have parens in right place. Print this line out as-is
			print "$line\n";
		}
		else
		{
			# Move the actual parens inside what's in left/right chunks
			$indexopen++;

			my $lineLeft = substr($line, 0, $indexopen); # up to (
			my $lineMid = substr($line, $indexopen, $indexclose - $indexopen); # between (), i.e. '10'
			my $lineRight = substr($line, $indexclose, 999999); # ) to end of line
			$lineMid = floor(($lineMid * $xScaleMultiplier) + 0.5);
			print "$lineLeft$lineMid$lineRight\n";
		}
	}
	elsif(($line =~ /^\s*Pos\(/i) || 
	   ($line =~ /^\s*Position\(/i) || 
	   ($line =~ /^\s*TabSize\(/i) || 
	   ($line =~ /^\s*CellSize\(/i) || 
	   ($line =~ /^\s*Size\(/i) || 
	   ($line =~ /^\s*Hotspot\(/i))
	{
		# Has 2 parameters, needing upscaling
		my $indexopen = index($line, "(");
		my $indexclose = index($line, ")");
		if(($indexopen == -1) || ($indexclose == -1) || ($indexclose < $indexopen))
		{
			# Doesn't have parens in right place. Print this line out as-is
			print "$line\n";
		}
		else
		{
			# Move the actual parens inside what's in left/right chunks
			$indexopen++;

			my $lineLeft = substr($line, 0, $indexopen); # up to (
			my $lineMid = substr($line, $indexopen, $indexclose - $indexopen); # between (), i.e. '5, 5'
			my $lineRight = substr($line, $indexclose, 999999); # ) to end of line

			# Read all parameters in the middle of the line
			my @myarray = split(',', $lineMid);

			$myarray[0] = floor(($myarray[0] * $xScaleMultiplier) + 0.5);
			$myarray[1] = floor(($myarray[1] * $yScaleMultiplier) + 0.5);

			# Reassemble the middle piece of the line, then the whole
			# line for output.
			$lineMid = join(', ', @myarray);
			print "$lineLeft$lineMid$lineRight\n";
		}
	}
	elsif($line =~ /^\s*Image\(/i)
	{
		my $indexopen = index($line, "(");
		my $indexclose = index($line, ")");
		if(($indexopen == -1) || ($indexclose == -1) || ($indexclose < $indexopen))
		{
			# Doesn't have parens in right place. Print this line out as-is
			print "$line\n";
		}
		else
		{
			# Move the actual parens inside what's in left/right chunks
			$indexopen++;
			my $lineLeft = substr($line, 0, $indexopen); # up to (
			my $lineMid = substr($line, $indexopen, $indexclose - $indexopen); # between (), i.e. '"colorize.tga", 7, 0'
			my $lineRight = substr($line, $indexclose, 999999); # ) to end of line

			my @myarray = split(',', $lineMid);

			my $arrayCount = scalar @myarray;

			# Upscale the image filename and texture coords, for colorize.tga ONLY
			if($myarray[0] =~ /colorize.tga/i)
			{
				$myarray[0] =~ s/\.tga/$filenameModifier\.tga/;
				# Has 1, 3 or 5 arguments. If 3 or 5, upscale the params past the first
				if($arrayCount == 5)
				{
					$myarray[3] = floor(($myarray[3] * $xScaleMultiplier) + 0.5);
					$myarray[4] = floor(($myarray[4] * $yScaleMultiplier) + 0.5);
				}
				if($arrayCount >= 3)
				{
					$myarray[1] = floor(($myarray[1] * $xScaleMultiplier) + 0.5);
					$myarray[2] = floor(($myarray[2] * $yScaleMultiplier) + 0.5);
				}
			}
			# Reassemble the middle piece of the line, then the whole
			# line for output.
			$lineMid = join(',',@myarray);
			print "$lineLeft$lineMid$lineRight\n";
		}
	}
	elsif($line =~ /^\s*Exec\(/i)
	{
		# Warn out if not on input filenames
		my $checkIndex = 2;
		my $bFound = 0;
		my @myarray = split('"', $line);
		for($checkIndex = 2; $checkIndex < ($numArgs); ++$checkIndex)
		{
			if($ARGV[$checkIndex] =~ /$myarray[1]/i)
			{
				$bFound = 1;
				break;
			}
		}
		if(!$bFound)
		{
			print STDERR " Extra file included: $line\n";
		}
		$line =~ s/.cfg/$filenameModifier.cfg/;
		print "$line\n";
	}
	else
	{
		# print this line out as-is
		print "$line\n";
	}
} # while($line = <INFILE>)

exit(0);


