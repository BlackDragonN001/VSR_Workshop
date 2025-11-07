#!/usr/bin/perl

use POSIX;

############################## Start Script ###################################

$numArgs = $#ARGV + 1;

if($numArgs < 4)
{
	print STDERR "Expected expandui.pl scaleNumberX scaleNumberY filenameModifier infile.cfg [infile2.cfg .. infileN.cfg]\n";
	print STDERR " e.g.   expandui.pl 2 2 _x2_0 bzgame_command.cfg bzgame_group.cfg\n";
	exit(1);
}

my $xScaleMultiplier = $ARGV[0];
my $yScaleMultiplier = $ARGV[1];

my $filenameModifier = $ARGV[2];

# Loop over all files
my $filenameIndex = 3;
for($filenameIndex = 3; $filenameIndex < ($numArgs); ++$filenameIndex)
{

	my $inFilename = $ARGV[$filenameIndex];
	my $outFilename = $inFilename;
#		print STDERR "Processing $inFilename -> $outFilename\n";
	$outFilename =~ s/.cfg/$filenameModifier.cfg/;

	if(!open(INFILE, "<$inFilename")) {
		print STDERR "$inFilename could not be read!\n";
		exit(1);
	} 

	if(!open(OUTFILE, ">$outFilename")) {
		print STDERR "$outFilename could not be written!\n";
		exit(1);
	} 


	my $line;
	while($line = <INFILE>)
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
				print OUTFILE "$line\n";
			}
			else
			{
				# Move the actual parens inside what's in left/right chunks
				$indexopen++;

				my $lineLeft = substr($line, 0, $indexopen); # up to (
				my $lineMid = substr($line, $indexopen, $indexclose - $indexopen); # between (), i.e. '10'
				my $lineRight = substr($line, $indexclose, 999999); # ) to end of line
				$lineMid = floor(($lineMid * $xScaleMultiplier) + 0.5);
				print OUTFILE "$lineLeft$lineMid$lineRight\n";
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
				print OUTFILE "$line\n";
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
				print OUTFILE "$lineLeft$lineMid$lineRight\n";
			}
		}
		elsif($line =~ /^\s*Image\(/i)
		{
			my $indexopen = index($line, "(");
			my $indexclose = index($line, ")");
			if(($indexopen == -1) || ($indexclose == -1) || ($indexclose < $indexopen))
			{
				# Doesn't have parens in right place. Print this line out as-is
				print OUTFILE "$line\n";
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
				print OUTFILE "$lineLeft$lineMid$lineRight\n";
			}
		}
		# elsif(($line =~ /^\s*Font\(/i) ||
		# 	  ($line =~ /^\s*TitleFont\(/i))
		# {
		# 	my @myarray = split('"', $line);
		# 	# Promote fonts one size up. Uppercase font name to make comparisons easier
		# 	$myarray[1] = uc($myarray[1]);

		# 	if($myarray[1] =~ "TINY")
		# 	{
		# 		$myarray[1] = "SMALL";
		# 	}
		# 	elsif($myarray[1] =~ "SMALL")
		# 	{
		# 		$myarray[1] = "MEDIUM";
		# 	}
		# 	elsif($myarray[1] =~ "MEDIUM")
		# 	{
		# 		$myarray[1] = "LARGE";
		# 	}

		# 	print OUTFILE join('"', @myarray);
		# 	print OUTFILE "\n";
		# }
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
			print OUTFILE "$line\n";
		}
		else
		{
			# print this line out as-is
			print OUTFILE "$line\n";
		}
	} # while($line = <INFILE>)


	close INFILE;
	close OUTFILE;
} # for($filenameIndex = 3; $filenameIndex < ($numArgs-1); ++$filenameIndex)

exit(0);


