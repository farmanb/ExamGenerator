#!/usr/bin/env perl
use strict;
use warnings;
use File::Path;

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

    my %report;
    my $exam = "";

    #Start Debug
    print "********** Building an exam for $student **********\n";
    #printStudentGrades($grades);
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
	    $report{$standard} = 1;
	}
    }

    #End the document.
    $exam .= "\n\\end{document}\n";

    checkExam($grades, \%report);
    
    #print "Problems on student's exam: \n";
    #print join "\n", @report;
    
    return $exam;
}

#Check to make sure that the student gets a problem for each standard they have not mastered.
sub checkExam{
    my ($gradesRef, $problemsRef) = (@_);

    foreach my $standard (keys %{$gradesRef}){
	if ($gradesRef->{$standard} ne "M" && !(exists $problemsRef->{$standard})){
	    print "Error:\n Standard: $standard\n Grade: $gradesRef->{$standard}\n Problem not included!\n "
	}
    }
}

my %gradeBook = createGradebook($standardsFile);

my @genericSourceLines;
my %problems;

parseExam($latexSourceFile, \@genericSourceLines, \%problems);

#Check the make sure that there is a problem for each of the standards.
#If not, alert and exit.
foreach my $standard (@standards){
    if (!exists $problems{$standard}){
	print "Error: There is no problem for " . $standard . "\n";
	exit;
    }
}

#Store the generic name line.  This is a kludge, but allows customization.
#After each student exam gets built, this is used to replace the entry in the generic source lines.
$nameLine = $genericSourceLines[$nameLineNum];

my $buildDir = 'build/tex';

#Check to see if the build directory exists
if (!(-e $buildDir and -d $buildDir)){
    #If one of the two fails, make sure there isn't something else with the same name.
    if (!(-e $buildDir)){
	#Create the build directory
	File::Path::make_path($buildDir);
	my $pdfDir = "$buildDir/../pdf";
	File::Path::make_path($pdfDir);
    }
}

foreach my $student (keys %gradeBook){
    #Create a file for the student's exam:
    my $fileBase = "exam03-161-$student";
    my $fileName = "$buildDir/$fileBase.tex";
    open(my $outfh, '>', $fileName) or die "Could not open file '$fileName' $!";
    
    print $outfh buildExam($student, \@genericSourceLines, \%problems,$gradeBook{$student});
    close $outfh or warn "Could not close '$fileName' $!";
}

#Batch compile the exams.
my $cmd = "cd build/tex && latexmk -silent -pdf && cp *.pdf ../pdf/";
system($cmd);
