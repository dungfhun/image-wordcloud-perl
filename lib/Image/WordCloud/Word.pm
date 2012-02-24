package Image::WordCloud::Word;

use namespace::autoclean;
use Moose;
use MooseX::Types::Moose qw(Str Int Num);
use Moose::Util::TypeConstraints;
use GD;
use GD::Text::Align;

use Image::WordCloud::Types qw(ArrayRefOfStrs Color Percent ImageSize Radians);
use Image::WordCloud::Word::BoundingBox;

#==============================================================================#
# Attributes
#==============================================================================#

#=================#
# Text attributes #
#=================#

has 'text' => (
	isa => Str,
	is  => 'ro',
	required => 1,
	trigger => \&_text_set
);
sub _text_set {
	my ($self, $new_text, $old_text) = @_;
	
	$self->gdtext->set_text( $new_text );
}
sub length { length( shift->text ) }

has 'color' => (
	is   => 'rw',
	isa  => Color,
	lazy => 1,
	default => sub { [0,0,0] },
	trigger => \&_color_set
);
sub _color_set {
	my ($self, $color) = @_;
	shift->gdtext->set(color => $color);
}

#=================#
# Font attributes #
#=================#

has 'fontsize'	=> (
	isa => Num,
	is => 'rw',
	trigger => \&_fontsize_set
);
sub _fontsize_set {
	my ($self, $fontsize) = @_;
	$self->gdtext->set_font( $self->font, $fontsize );
}

has 'font' => (
	isa => Str,
	is => 'rw',
	trigger => \&_font_set
);
sub _font_set {
	my ($self, $font) = @_;
	$self->gdtext->set_font( $font, $self->fontsize );
}

# Get and set the font+fontsize at the same time
sub font_and_size {
	my ($self, $font, $fontsize) = @_;
	
	if (! defined $font || ! defined $fontsize) {
		return ($self->font, $self->fontsize);
	}
	else {
		$self->font( $font )->size( $fontsize );
	}
}

#===============#
# Inner objects #
#===============#

has 'gd' => (
	isa => 'GD::Image',
	is  => 'ro',
	required => 1,
);

has 'gdtext' => (
	isa => 'GD::Text::Align',
	is  => 'ro',
	init_arg => undef,
	default  => sub { GD::Text::Align->new( shift->gd ) },
);

#=====================#
# Position attributes #
#=====================#

sub width  { return shift->gdtext->get('width')  }
sub height { return shift->gdtext->get('height') }

sub gdtext_bounding_box {
	my $self = shift;
	my ($x, $y, $angle) = @_;
	
	$x = $self->x if ! defined $x;
	$y = $self->y if ! defined $y;
	
	$angle ||= 0;
	
	return $self->gdtext->bounding_box($x, $y, $angle);
}

# x,y coordinates
has [ 'x', 'y' ] => ( isa => Num, is => 'rw', default => 0 );
sub xy {
	my $self = shift;
	
	my ($x, $y) = @_;
	
	if (defined $x && defined $y) {
		$self->x($x);
		$self->y($y);
		
		return $self;
	}
	else {
		return ($self->x, $self->y);
	}
}

has 'angle' => (
	isa => Radians,
	is => 'rw',
	lazy    => 1,
	default => 0,
	coerce  => 1,
);

# Bounding box around this word
has 'boundingbox' => (
	isa => 'Image::WordCloud::Word::BoundingBox',
	is  => 'ro',
	init_arg => undef,
	lazy    => 1,
	builder => '_build_boundingbox',
	#default => sub { Image::WordCloud::Word::BoundingBox->new(word => shift) }
);

sub _build_boundingbox {
	my $self = shift;
	
	return Image::WordCloud::Word::BoundingBox->new(
		word    => $self,
		lefttop => [$self->x, $self->y],
		width   => $self->width,
		height  => $self->height,
	);
}

#==============================================================================#
# Methods
#==============================================================================#

#=============#
# Positioning #
#=============#



#============#
# Collisions #
#============#

# Return true if this word collides with another
sub collides {
	my ($self, $word) = @_;
	
	return $self->collides_at($word, $self->xy);
}

# Return true if this word collides with another at specific coordinates
sub collides_at {
	my ($self, $word, $x, $y) = @_;
	
	return $self->boundingbox->collides_at( $word->boundingbox, $x, $y );
}

#=========#
# Drawing #
#=========#

# Draw the word on the given GD::Image object
sub draw {
	my $self   = shift;
	my ($x, $y, $angle) = @_;
	
	$x = $self->x if ! defined $x;
	$y = $self->y if ! defined $y;
	
	$angle ||= 0;
	
	#my $gd = shift || $self->gd;
	my $gd = $self->gd;
	
	my $color = $gd->colorAllocate( @{ $self->color } );
	
	# Make a clone of our GD::Text::Align object so we can draw it on the passed-in GD image
	my $text = GD::Text::Align->new( $gd, color => $color );
	$text->set_font( $self->font, $self->fontsize );
	$text->set_text( $self->text );
	
	# Draw the text
	return $text->draw($x, $y, $angle);
}

# Return an image with the bounding boxes stroked
sub boundingbox_image {
	my $self = shift;
	
	return $self->boundingbox->boximage();
}

sub stroke_bbox {
	my $self = shift;
	
	my $boxlist = $self->boundingbox->_offset_boxes( $self->boundingbox->box );
	
	foreach my $box (@$boxlist) {
		$self->gd->filledRectangle(@{ $box->{tl} }, @{ $box->{br} }, $self->boundingbox->gd_hightlight_fillcolor);
			
		$self->gd->rectangle(@{ $box->{tl} }, @{ $box->{br} }, $self->boundingbox->gd_highlightcolor);
	}
	
	return $self;
}

sub stroke_bbox_outline {
	my $self = shift;
	
	$self->boundingbox->_allocateColors;
	$self->gd->rectangle($self->boundingbox->left, $self->boundingbox->top, $self->boundingbox->right, $self->boundingbox->bottom, $self->boundingbox->gd_highlightcolor);
	
	return $self;
}

__PACKAGE__->meta->make_immutable;

1;