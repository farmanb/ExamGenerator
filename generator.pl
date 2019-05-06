#!/usr/bin/env perl
use strict;
use warnings;

my $standardsFile = "standards.csv";
my $latexSourceFile = "exam03-161.tex";
my $nameLineNum = -1;
my $nameLine;
my @standards;

#Pretty print the whole gradebook.
sub printGradebook{
    my $gradebookRef = shift;

    foreach my $name (keys %{$gradebookRef}){
	my %grades = %{$gradebookRef->{$name}};
	printStudentGrades(\%grades);
	#print $name . "\n";
	#foreach my $standard (keys %grades){
	#print "\t$standard: " . $grades{$standard} . "\n";
	#}
    }
}

#Pretty print a student's grade.
sub printStudentGrades{
    my $grades = shift;
    foreach my $standard (keys %{$grades}){
	print $standard . ": " . $grades->{$standard} . "\n";
    }
}

sub createGradebook{
    my $fileName = shift;
    my $last;
    my $first;
    open(my $fh, "<", $fileName) or die "Can't open < $standardsFile: $!";

    my $firstLine = <$fh>;
    chomp $firstLine;
    
    ($last, $first, @standards) = split ',', $firstLine;

    my %gradeBook;
    while (my $row = <$fh>) {
	chomp $row;
	($last,$first,my @masteryLevels) = split ',', $row;
	my %grades;
	foreach my $i (0..$#standards){
	    $grades{$standards[$i]} = $masteryLevels[$i];
	}
	$gradeBook{"$first $last"} = \%grades;
    }

    return %gradeBook;
}

sub parseExam{
    my ($latexSourceFile,$genericSourceLines, $problems) = (@_);

    print $latexSourceFile;

    my $isGeneric = 1;
    my $sectionName;
    my @sectionData;
    
    open(my $fh, "<", $latexSourceFile) or die "Can't open < $latexSourceFile: $!";

    while (my $row = <$fh>){
	chomp $row;
	if ($row =~ m/\\section\*\{(.*)\}/){
	    $isGeneric = 0;
	    $sectionName = $1;
	    #print "This is the beginning of the section on $sectionName\n";
	}
	if ($row =~ m/\%End/ || $row =~m/\\end\{document\}/){
	    #print "This is the end of the section on $sectionName\n";
	    $isGeneric = 1;
	    $problems->{$sectionName} = join "\n", @sectionData;
	    @sectionData = ();
	    next;
	}

	if ($isGeneric){
	    if ($row =~ m/\<Student Name\>/){
		$nameLineNum = $#{$genericSourceLines} + 1;
	    }
	    push @{$genericSourceLines}, $row;
	}else{
	    push @sectionData, $row;
	}
    }

    close $fh or warn "close failed: $!";
}

sub buildExam{
    my ($student, $genericSourceLines, $problems, $grades) = (@_);
    my $exam = "";

    #Start Debug
    print "********** Building an exam for $student **********\n";
    printStudentGrades($grades);
    #End Debug
    
    #This adds the student's name on the Name Line.
    $genericSourceLines->[$nameLineNum] =~ s/\<Student Name\>/$student/;

    #Print all the generic stuff before the content.
    $exam .=  join "\n", @{$genericSourceLines};

    #Replace the name line
    $genericSourceLines->[$nameLineNum] = $nameLine;

    #Grab the grades for the student.
    #my $hashRef = $gradeBook{$student};

    #Iterate over the standards being tested.
    foreach my $standard (@standards){
	#If the student hasn't mastered the standard yet, print the problems from that standard.
	if ($grades->{$standard} ne "M"){ 
	    $exam .= "$problems->{$standard}\n";
	}
    }

    #End the document.
    $exam .= "\n\\end{document}\n";

    return $exam;
}

my %gradeBook = createGradebook($standardsFile);

my @genericSourceLines;
my %problems;

parseExam($latexSourceFile, \@genericSourceLines, \%problems);

#Store the generic name line.  This is a kludge, but allows customization.
#After each student exam gets built, this is used to replace the entry in the generic source lines.
$nameLine = $genericSourceLines[$nameLineNum];

foreach my $student (keys %gradeBook){
    #Create a file for the student's exam:
    my $fileBase = "exam03-161-$student";
    my $filename = "build/tex/$fileBase.tex";
    open(my $outfh, '>', $filename) or die "Could not open file '$filename' $!";

    #Takes a student name, the generic source, problems, and the student's grades.
    #my $exam = 
    
    #This adds the student's name on the Name Line.
    #$genericSourceLines[$nameLineNum] =~ s/\<Student Name\>/$student/;

    #Print all the generic stuff before the content.
    #print $outfh join "\n", @genericSourceLines;

    #Replace the name line
    #$genericSourceLines[$nameLineNum] = $nameLine;

    #Grab the grades for the student.
    #my $hashRef = $gradeBook{$student};

    #Iterate over the standards being tested.
    #foreach my $standard (@standards){
	#If the student hasn't mastered the standard yet, print the problems from that standard.
	#if ($hashRef->{$standard} ne "M"){ 
	#    print $outfh "$problems{$standard}\n";
	#}
    #}

    #End the document.
    #print $outfh "\n\\end{document}\n";
    print $outfh buildExam($student, \@genericSourceLines, \%problems,$gradeBook{$student});
    close $outfh or warn "Coud not close '$filename' $!";

    my $cmd = "cd build/tex && latexmk -silent -pdf '$fileBase.tex' && mv '$fileBase.pdf' ../pdf/ && cd ..";
    system($cmd);
}
