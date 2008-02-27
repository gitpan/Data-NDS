package Data::NDS;
# Copyright (c) 2008-2008 Sullivan Beck. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

########################################################################
# TODO
########################################################################

# Add validity tests for data
# see Data::Domain, Data::Validator

# Add identical (to see if two NDSes are identical), contains (to
# see if all non-empty parts in one NDS are identical to those in
# the other)
# see Data::Validate::XSD

# Add subtract (to remove items in one NDS from another)
# see Data::Validate::XSD

# Add search (to return paths to data that match certain criteria)
# see Data::Search

# Add clean (to remove empty paths)

########################################################################
# HISTORY
########################################################################

# Version 1.00   2008-02-27
#    Initial release

$VERSION = "1.00";

########################################################################

require 5.000;
use strict;
use Storable qw(dclone);

use vars qw($VERSION);

###############################################################################
# BASE METHODS
###############################################################################
#
# The Data::NDS object is a hash of the form:
#
# { warn      => FLAG                                    whether to warn
#   delim     => DELIMITER                               the path delimiter
#   nds       => { NAME       => NDS }                   named NDSes
#   structure => FLAG                                    whether to do structure
#   struct    => { PATH       => { ITEM => VAL } }       structural information
#   defstruct => { ITEM       => VAL }                   default structure
#   merge     => { RULESET    => { PATH   => VAL } }     per path merge methods
#   defmerge  => { RULESET    => { ITEM   => VAL } }     default merge methods
# }

sub new {
  my($class) = @_;

  my $self = {
              "warn"      => 0,
              "delim"     => "/",
              "nds"       => {},
              "structure" => 1,
              "struct"    => {},
              "defstruct" => {},
              "merge"     => {},
              "defmerge"  => {},
             };
  _structure_defaults($self);
  _merge_defaults($self);
  bless $self, $class;

  return $self;
}

sub version {
   my($self) = @_;

   return $VERSION;
}

sub warnings {
   my($self,$val) = @_;

   $$self{"warn"} = $val;
}

sub structure {
   my($self,$val) = @_;

   $$self{"structure"} = $val;
}

sub _warn {
   my($self,$message,$force) = @_;
   return  unless ($$self{"warn"}  ||  $force);
   warn "$message\n";
}

sub ruleset {
   my($self,$name) = @_;
   return 3  if ($name eq "keep"  ||  $name eq "replace");
   return 1  if ($name !~ /^[a-zA-Z0-9]+$/);
   return 2  if (exists $$self{"merge"}{$name});
   $$self{"merge"}{$name} = {};
   $$self{"defmerge"}{$name} = {};
   return 0;
}

###############################################################################
# PATH METHODS
###############################################################################

sub delim {
   my($self,$delim) = @_;
   if (! defined $delim) {
      return $$self{"delim"};
   }
   $$self{"delim"} = $delim;
}

sub path {
   my($self,$path) = @_;
   my($delim) = $self->delim();
   my(@path);
   if ($path  &&  ref($path)) {
      @path = @$path;
   } elsif (! $path  ||
            $path eq $delim) {
      @path = ();
   } else {
      $path      =~ s/^\Q$delim\E//;
      @path   = split(/\Q$delim\E/,$path);
   }

   return @path  if (wantarray);
   return $delim . join($delim,@path);
}

###############################################################################
# NDS METHODS
###############################################################################

sub nds {
   my($self,$name,$nds,$new) = @_;

   #
   # $obj->nds($name);
   #

   if (! defined $nds) {
      if (exists $$self{"nds"}{$name}) {
         return $$self{"nds"}{$name};
      } else {
         return undef;
      }
   }

   #
   # $obj->nds($name,"_delete");
   #

   if ($nds eq "_delete") {
      delete $$self{"nds"}{$name}  if (exists $$self{"nds"}{$name});
      return;
   }

   #
   # $obj->nds($name,$nds);
   # $obj->nds($name,$nds,$new);
   #

   if (ref($nds)) {
      my($err,$val) = $self->check_structure($nds,$new);
      return ($err)  if ($err);
      $$self{"nds"}{$name} = dclone($nds);
      return 0;

   } elsif (exists $$self{"nds"}{$nds}) {
      $$self{"nds"}{$name} = dclone($$self{"nds"}{$nds});
      return 0;

   } else {
      return -1;
   }
}

sub empty {
   my($self,$nds) = @_;
   return _empty($nds);
}

sub _empty {
   my($nds) = @_;

   if (! defined $nds) {
      return 1;

   } elsif (ref($nds) eq "ARRAY") {
      return 1  if ($#$nds == -1);
      foreach my $ele (@$nds) {
         return 0  if (! _empty($ele));
      }
      return 1;

   } elsif (ref($nds) eq "HASH") {
      return 1  if (scalar(keys %$nds) == 0);
      foreach my $key (keys %$nds) {
         return 0  if (! _empty($$nds{$key}));
      }
      return 1;

   } elsif (! ref($nds)) {
      return 1  if ($nds eq "");
      return 0;

   } else {
      return 0;
   }
}

###############################################################################
# KEYS, VALUES
###############################################################################

sub keys {
   my($self,$nds,$path) = @_;
   my($valid,$val) = $self->valid($nds,$path);

   return undef  if (! $valid);

   if (! ref($val)) {
      return ();

   } elsif (ref($val) eq "ARRAY") {
      return (0..$#$val);

   } elsif (ref($val) eq "HASH") {
      return sort (CORE::keys %$val);

   } else {
      return undef;
   }
}

sub values {
   my($self,$nds,$path) = @_;
   my($valid,$val) = $self->valid($nds,$path);

   return undef  if (! $valid);

   if (! ref($val)) {
      return ($val);

   } elsif (ref($val) eq "ARRAY") {
      return @$val;

   } elsif (ref($val) eq "HASH") {
      return sort (CORE::values %$val);

   } else {
      return undef;
   }
}

###############################################################################
# VALID
###############################################################################
# Checks to see if a path is valid in an NDS

sub valid {
   my($self,$nds,$path) = @_;
   my($delim) = $self->delim();
   my @path   = $self->path($path);
   if (! ref($nds)) {
      $nds = $self->nds($nds);
   }
   if (! ref($nds)) {
      return (0,-1);
   }

   return _valid($nds,$delim,"",@path);
}

sub _valid {
   my($nds,$delim,$path,@path) = @_;

   #
   # We've traversed as far as @path goes
   #

   return (1,$nds)  if (! @path);

   #
   # Get the next path element.
   #

   my $p = shift(@path);
   $path = ($path ? join($delim,$path,$p) : "/$p");

   #
   # Handle the case where $nds is a scalar, or not
   # a known data type.
   #

   if      (! defined($nds)) {
      # $nds doesn't contain the path
      return (0,0,$path);

   } elsif (! ref($nds)) {
      # $nds is a scalar
      return (0,10,$path);

   } elsif (ref($nds) ne "HASH"  &&  ref($nds) ne "ARRAY") {
      # $nds is an unsupported data type
      return (0,11,$path);
   }

   #
   # Handle hash references.
   #

   if      (ref($nds) eq "HASH") {
      if (exists $$nds{$p}) {
         return _valid($$nds{$p},$delim,$path,@path);
      } else {
         return (0,1,$path);
      }
   }

   #
   # Handle lists.
   #

   if ($p !~ /^\d+$/) {
      return (0,12,$path);
   } elsif (defined $$nds[$p]) {
      return _valid($$nds[$p],$delim,$path,@path);
   } else {
      return (0,2,$path);
   }
}

###############################################################################
# MERGE
###############################################################################
# This merges two NDSes into a single one.

sub merge {
   my($self,$nds1,$nds2,@args) = @_;

   #
   # Get nds1 and nds2 by reference or name
   #

   if (! ref($nds1)) {
      $nds1 = $self->nds($nds1);
      if (! defined($nds1)) {
         _warn($self,"[merge] NDS1 undefined: $nds1");
         return 1;
      }
   }

   if (! ref($nds2)) {
      $nds2 = $self->nds($nds2);
      if (! defined($nds2)) {
         _warn($self,"[merge] NDS2 undefined: $nds2");
         return 1;
      }
   }

   #
   # Parse ruleset and new arguments
   #

   my ($ruleset,$new);
   if (! @args) {
      $ruleset = "*";
      $new     = 0;

   } elsif ($#args == 0) {
      if ($args[0] eq "0"  ||  $args[0] eq "1") {
         $ruleset = "*";
         $new     = $args[0];
      } else {
         $ruleset = $args[0];
         $new     = 0;
      }

   } elsif ($#args == 1) {
      $ruleset = $args[0];
      $ruleset = $args[1];

   } else {
      die "[merge] Unknown argument list";
   }

   #
   # Check structure
   #

   my ($err,$val) = $self->check_structure($nds1,$new);
   return 3  if ($err);
   ($err,$val) = $self->check_structure($nds2,$new);
   return 4  if ($err);

   #
   # Merge
   #

   $nds1 = _merge($self,$nds1,$nds2,[],$ruleset);
   return 0;
}

sub _merge {
   my($self,$nds1,$nds2,$pathref,$ruleset) = @_;
   my $path = $self->path($pathref);

   #
   # If $nds2 is empty, we'll always return whatever $nds1 is.
   # If $nds1 is empty, we'll always return a copy of whatever $nds2 is.
   #

   return $nds1  if ($self->empty($nds2));
   if ($self->empty($nds1)) {
      if (ref($nds2)) {
         return dclone($nds2);
      } else {
         return $nds2;
      }
   }

   #
   # $method can be merge, keep, keep_warn, replace, replace_warn,
   # error, append
   #
   # handle keep*, replace*, and error
   #

   my $type   = $self->get_structure($path);
   my $method = $self->get_merge($path,$ruleset);

   if      ($method eq "keep"  ||  $method eq "keep_warn") {
      _warn($self,"[merge] keeping initial value\n" .
                  "        path: $path",1)  if ($method eq "keep_warn");
      return $nds1;

   } elsif ($method eq "replace"  ||  $method eq "replace_warn") {
      _warn($self,"[merge] replacing initial value\n" .
                  "        path: $path",1)  if ($method eq "replace_warn");
      if (ref($nds2)) {
         return dclone($nds2);
      }
      return $nds2;

   } elsif ($method eq "error") {
      if (ref($nds1)) {
         _warn($self,"[merge] multiply defined value\n" .
                     "        path: $path",1);
         exit;
      } elsif ($nds1 eq $nds2) {
         return $nds1;
      } else {
         _warn($self,"[merge] nonidentical values\n" .
                     "        path: $path",1);
         exit;
      }
   }

   #
   # Merge two lists
   #

   if (ref($nds1) eq "ARRAY") {
      return _merge_lists($self,$method,$nds1,$nds2,$pathref,$ruleset);
   }

   #
   # Merge two hashes
   #

   if (ref($nds1) eq "HASH") {
      return _merge_hashes($self,$method,$nds1,$nds2,$pathref,$ruleset);
   }
}

# Method is: merge
#
sub _merge_hashes {
   my($self,$method,$val1,$val2,$pathref,$ruleset) = @_;

   foreach my $key (CORE::keys %$val2) {
      next  if ($self->empty($$val2{$key}));

      if (! exists $$val1{$key}  ||
          $self->empty($$val1{$key})) {
         if (ref($$val2{$key})) {
            $$val1{$key} = dclone($$val2{$key});
         } else {
            $$val1{$key} = $$val2{$key};
         }

      } else {
         $$val1{$key} =
           _merge($self,$$val1{$key},$$val2{$key},[@$pathref,$key],$ruleset);
      }
   }

   return $val1;
}

# Method is: append, merge
#
sub _merge_lists {
   my($self,$method,$val1,$val2,$pathref,$ruleset) = @_;

   # Handle append unordered

   if ($method eq "append") {
      push(@$val1,@{ dclone($val2) });
      return $val1;
   }

   # Handle merge ordered (merge each i'th element)

   my($i);
   for ($i=0; $i<=$#$val2; $i++) {

      # val1[i]  val2[i]
      # -------  -------
      # *        empty      do nothing
      # empty    *          val1[i] = val2[i]
      # *        *          recurse into (including scalars)

      if ($self->empty($$val2[$i])) {
         next;

      } elsif ($self->empty($$val1[$i])) {
         if (ref($$val2[$i])) {
            $$val1[$i] = dclone($$val2[$i]);
         } else {
            $$val1[$i] = $$val2[$i];
         }

      } else {
         $$val1[$i] =
           _merge($self,$$val1[$i],$$val2[$i],[@$pathref,$i],$ruleset);
      }
   }

   return $val1;
}

###############################################################################
# SET_STRUCTURE
###############################################################################
# This sets a piece of structural information (and does all error checking
# on it).

sub set_structure {
   my($self,$item,$val,$path) = @_;

   if ($path) {
      return _set_structure_path($self,$item,$val,$path);
   } else {
      return _set_structure_default($self,$item,$val);
   }
}

# Set a structural item for a path.
#
sub _set_structure_path {
   my($self,$item,$val,$path) = @_;

   my @path = $self->path($path);
   $path    = $self->path(\@path);
   return _structure_valid($self,$item,$val,$path,@path);
}

# Rules for a valid structure:
#
# If parent is not valid
#    INVALID
# End
#
# If we're not setting an item
#    VALID
# End
#
# If type is not set
#    set it to unknown
# End
#
# INVALID  if incompatible with any other options already set
# INVALID  if path incompatible with type
# INVALID  if path incompatible with parent
# INVALID  if any direct childres incompatible
#
# Set item
#
sub _structure_valid {
   my($self,$item,$val,$path,@path) = @_;

   #
   # Check for an invalid parent
   #

   my (@parent,$parent);
   if (@path) {
      @parent = @path;
      pop(@parent);
      $parent = $self->path([@parent]);
      my $err = _structure_valid($self,"","",$parent,@parent);
      return $err  if ($err);
   }

   #
   # If we're not setting a value, then the most we've done is
   # set defaults (which we know we've done correct), so it's valid
   # to the extent that we're able to check.
   #

   return 0  unless ($item);

   #
   # Make sure type is set. If it's not, set it to "unknown".
   #

   $$self{"struct"}{$path}{"type"} = "unknown"
     if (! exists $$self{"struct"}{$path}{"type"});
   my $type = $$self{"struct"}{$path}{"type"};

   #
   # Check to make sure that $item and $val are valid and that
   # they don't conflict with other structural settings for
   # this path.
   #

   my $set_ordered    = 0;
   my $set_uniform    = 0;
   my $valid          = 0;

   # Type checks
   if ($item eq "type") {
      $valid = 1;
      if ($val ne "scalar"  &&
          $val ne "array"   &&
          $val ne "hash"    &&
          $val ne "other") {
         _warn($self,"[structure] Type invalid: $val");
         return 1;
      }
      if ($type ne "unknown"  &&
          $type ne "array/hash") {
         _warn($self,"[structure] Type already set: $val");
         return 2;
      }
      if ($type eq "array/hash"  &&
          $val ne "array"        &&
          $val ne "hash") {
         _warn($self,"[structure] Array or hash type required: $val");
         return 3;
      }
   }

   # Ordered checks
   if ($item eq "ordered") {
      $valid = 1;
      if (exists $$self{"struct"}{$path}{"ordered"}) {
         _warn($self,"[structure] Ordered already set");
         return 102;
      }

      # only allowed for arrays
      if ($type eq "unknown"  ||
          $type eq "array/hash") {
         my $err = _structure_valid($self,"type","array",$path,@path);
         return $err  if ($err);
         $type = "array";
      }
      if ($type ne "array") {
         _warn($self,"[structure] Ordered only applies to arrays");
         return 101;
      }
      if ($val ne "0"  &&
          $val ne "1") {
         _warn($self,"[structure] Ordered may only be 0 or 1");
         return 100;
      }

      # check conflicts with "uniform"
      if (! exists $$self{"struct"}{$path}{"uniform"}) {
         if ($val) {
            # We're making an unknown array ordered. This can
            # apply to uniform or non-uniform arrays, so nothing
            # is required.
         } else {
            # We're making an unknown array unordered. The
            # list must be uniform.
            $set_uniform = 1;
         }
      } elsif ($$self{"struct"}{$path}{"uniform"}) {
         # We're making an uniform list ordered or non-ordered.
         # Both are allowed.
      } else {
         if ($val) {
            # We're making an non-uniform list ordered. This is
            # allowed.
         } else {
            # We're trying to make an non-uniform list unordered.
            # This is NOT allowed.
            _warn($self,"[structure] A non-uniform list must be ordered");
            return 103;

            # NOTE: This error will never be returned. Any time we set a
            # list to non-uniform, it will automatically set the ordered
            # flag appropriately, so trying to set it here will result in
            # a 102 error.
         }
      }
   }

   # Uniform checks
   if ($item eq "uniform") {
      $valid = 1;
      if (exists $$self{"struct"}{$path}{"uniform"}) {
         _warn($self,"[structure] Uniform already set");
         return 112;
      }

      # only applies to arrays and hashes
      if ($type eq "unknown") {
         my $err = _structure_valid($self,"type","array/hash",$path,@path);
         return $err  if ($err);
      }
      if ($type ne "array"  &&
          $type ne "hash"   &&
          $type ne "array/hash") {
         _warn($self,"[structure] Uniform only applies to arrays and hashes");
         return 111;
      }
      if ($val ne "0"  &&
          $val ne "1") {
         _warn($self,"[structure] Uniform may only be 0 or 1");
         return 110;
      }

      # check conflicts with "ordered"
      if (exists $$self{"struct"}{$path}{"type"}  &&
          $$self{"struct"}{$path}{"type"} eq "array") {
         if (! exists $$self{"struct"}{$path}{"ordered"}) {
            if ($val) {
               # We're making an unknown array uniform. This can
               # apply to ordered or unorderd arrays, so nothing
               # is required.
            } else {
               # We're making an unknown array non-uniform. The
               # list must be ordered.
               $set_ordered = 1;
            }
         } elsif ($$self{"struct"}{$path}{"ordered"}) {
            # We're making an ordered list uniform or non-uniform.
            # Both are allowed.
         } else {
            if ($val) {
               # We're making an unordered list uniform. This is
               # allowed.
            } else {
               # We're trying to make an unordered list non-uniform.
               # This is NOT allowed.
               _warn($self,"[structure] An unordered list must be uniform");
               return 113;

               # NOTE: This error will never be returned. Any time we set a
               # list to unordered, it will automatically set the uniform
               # flag appropriately, so trying to set it here will result in
               # a 112 error.
            }
         }
      }
   }

   # $item is invalid
   if (! $valid) {
      _warn($self,"[structure] Invalid structural item: $item");
      return 11;
   }

   #
   # Check to make sure that the current path is valid with
   # respect to the type of structure we're currently in (this
   # is defined in the parent element).
   #

   if (@path) {
      my $curr_ele    = $path[$#path];
      if (exists $$self{"struct"}{$parent}{"type"}) {
         my $parent_type = $$self{"struct"}{$parent}{"type"};

         if ($parent_type eq "unknown") {
            my $err = _structure_valid($self,"type","array/hash",
                                       $parent,@parent);
            return $err  if ($err);
         }

         if ($parent_type eq "scalar"  ||
             $parent_type eq "other") {
            _warn($self,
                  "[structure] Intermediate path elements must be either\n" .
                  "            array or hash: $parent");
            return 130;

         } elsif ($parent_type eq "array"  &&
             $curr_ele =~ /^\d+$/) {
            if (exists $$self{"struct"}{$parent}{"uniform"}) {
               if ($$self{"struct"}{$parent}{"uniform"}) {
                  # Parent = array,uniform  Curr = 2
                  _warn($self,
                        "[structure] Cannot set structural information for\n" .
                        "            an individual element in a uniform list");
                  return 140;
               }
            } else {
               # Parent = array, unknown  Curr = 2
               #    => force parent to be non-uniform
               my $err = _structure_valid($self,"uniform","0",$parent,@parent);
               return $err  if ($err);
            }

         } elsif ($parent_type eq "array"  &&
                  $curr_ele eq "*") {
            if (exists $$self{"struct"}{$parent}{"uniform"}) {
               if (! $$self{"struct"}{$parent}{"uniform"}) {
                  # Parent = array,nonuniform  Curr = *
                  _warn($self,
                        "[structure] Cannot set structural information for\n" .
                        "            all elements in a non-uniform list");
                  return 141;
               }
            } else {
               # Parent = array,unknown  Curr = *
               #    => force parent to be uniform
               my $err = _structure_valid($self,"uniform","1",$parent,@parent);
               return $err  if ($err);
            }

         } elsif ($parent_type eq "array") {
            _warn($self,
                  "[structure] List element not defined with an integer index");
            return 150;

         } elsif (($parent_type eq "hash"  ||  $parent_type eq "array/hash")  &&
                  $curr_ele eq "*") {
            if (exists $$self{"struct"}{$parent}{"uniform"}) {
               if (! $$self{"struct"}{$parent}{"uniform"}) {
                  # Parent = array/hash,non-uniform  Curr = *
                  _warn($self,
                        "[structure] Cannot set structural information for\n".
                        "            all elements in a non-uniform structure\n".
                        "            (could be hash or array)");
                  return 161;
               }
            } else {
               # Parent = hash,unknown  Curr = *
               #    => force parent to be uniform
               my $err = _structure_valid($self,"uniform","1",$parent,@parent);
               return $err  if ($err);
            }

         } elsif ($parent_type eq "hash"  ||  $parent_type eq "array/hash") {
            if (exists $$self{"struct"}{$parent}{"uniform"}) {
               if ($$self{"struct"}{$parent}{"uniform"}) {
                  # Parent = array/hash,uniform  Curr = foo
                  _warn($self,
                        "[structure] Cannot set structural information for\n" .
                        "            an individual element in a uniform\n".
                        "             structure (could be hash or array)");
                  return 160;
               }
            } else {
               # Parent = hash,unknown  Curr = foo
               #    => force parent to be non-uniform
               my $err = _structure_valid($self,"uniform","0",$parent,@parent);
               return $err  if ($err);
            }
         }

      } else {
         # Parent is not type'd yet.

         if ($curr_ele eq "*"  ||
             $curr_ele =~ /^\d+$/) {
            my $err = _structure_valid($self,"type","array/hash",
                                       $parent,@parent);
            return $err  if ($err);
         } else {
            my $err = _structure_valid($self,"type","hash",
                                       $parent,@parent);
            return $err  if ($err);
         }
      }
   }

   #
   # Set the item
   #

   $$self{"struct"}{$path}{$item} = $val;
   if ($set_ordered) {
      my $err = _structure_valid($self,"ordered","1",$path,@path);
      return $err  if ($err);
   }
   if ($set_uniform) {
      my $err = _structure_valid($self,"uniform","1",$path,@path);
      return $err  if ($err);
   }
}

{
   # Values for the default structural information. First value in the
   # list is the error code for this item. Second value is the default
   # for this item.

   my %def = ( "ordered"        => [ 170, qw(0 1) ],
               "uniform_hash"   => [ 180, qw(0 1) ],
               "uniform_ol"     => [ 181, qw(1 0) ],
             );

   sub _set_structure_default {
      my($self,$item,$val) = @_;

      if (! exists $def{$item}) {
         _warn($self,"[structure] Invalid item for default: $item");
         return 10;
      }
      my @tmp = @{ $def{$item} };
      my $err = shift(@tmp);
      my %tmp = map { $_,1 } @tmp;
      if (! exists $tmp{$val}) {
         _warn($self,"[structure] Invalid value for default: $item = $val");
         return $err;
      }
      $$self{"defstruct"}{$item} = $val;
      return 0;
   }

   # Set up the default structure:
   sub _structure_defaults {
      my($self) = @_;
      my($d) = "defstruct";

      $$self{$d} = {}  if (! exists $$self{$d});
      foreach my $key (CORE::keys %def) {
         $$self{$d}{$key} = $def{$key}[1];
      }
   }
}

###############################################################################
# SET_MERGE
###############################################################################

sub set_merge {
   my($self,$item,$val,@args) = @_;

   if (_merge_default($self,$item)) {
      return _set_merge_default($self,$item,$val,@args);

   } elsif ($item eq "merge") {
      return _set_merge_path($self,$val,@args);

   } else {
      _warn($self,"[set_merge] Invalid item for default: $item");
      return 10;
   }
}

# Set a merge item for a path.
#
sub _set_merge_path {
   my($self,$path,$method,$ruleset) = @_;
   $ruleset = "*"  if (! $ruleset);

   my @path = $self->path($path);
   $path    = $self->path(\@path);

   if (exists $$self{"merge"}{$ruleset}{$path}) {
      _warn($self,"[set_merge] Method already set for path: $path");
      return 120;
   }

   # Check type vs. method

   my $type = $self->get_structure($path,"type");

   if      ($type eq "array") {
      my $ordered = $self->get_structure($path,"ordered");

      if (! _merge_allowed($type,$ordered,$method)) {
         if ($ordered) {
            _warn($self,
                  "[set_merge] Method not allowed for ordered list: $method");
            return 130;
         } else {
            _warn($self,
                  "[set_merge] Method not allowed for unordered list: $method");
            return 131;
         }
      }

   } elsif ($type eq "hash") {
      if (! _merge_allowed($type,0,$method)) {
         _warn($self,"[set_merge] Method not allowed for hash: $method");
         return 132;
      }

   } elsif ($type eq "scalar"  ||  $type eq "other") {
      if (! _merge_allowed($type,0,$method)) {
         _warn($self,"[set_merge] Method not allowed for scalar: $method");
         return 133;
      }

   } else {
      _warn($self,"[set_merge] Unknown type: $path");
      return 121;
   }

   # Set the method

   $$self{"merge"}{$ruleset}{$path} = $method;
   return 0;
}

{
   # Values for the default structural information. First value in the
   # list is the error code for this item. Second value is the default
   # for this item.

   my %def = ( "merge_hash"     => [ 100, qw(merge
                                             keep keep_warn
                                             replace replace_warn
                                             error) ],
               "merge_ol"       => [ 101, qw(merge
                                             keep keep_warn
                                             replace replace_warn
                                             error) ],
               "merge_ul"       => [ 102, qw(append
                                             keep keep_warn
                                             replace replace_warn
                                             error) ],
               "merge_scalar"   => [ 103, qw(keep keep_warn
                                             replace replace_warn
                                             error) ],
             );

   sub _merge_default {
      my($self,$item) = @_;
      return 1  if (exists $def{$item});
      return 0;
   }

   sub _set_merge_default {
      my($self,$item,$val,$ruleset) = @_;
      $ruleset = "*"  if (! $ruleset);

      my @tmp = @{ $def{$item} };
      my $err = shift(@tmp);
      my %tmp = map { $_,1 } @tmp;
      if (! exists $tmp{$val}) {
         _warn($self,"[set_merge_default] Invalid value for default: $item = $val");
         return $err;
      }
      $$self{"defmerge"}{$ruleset}{$item} = $val;
      return 0;
   }

   # Set up the default merge:
   sub _merge_defaults {
      my($self) = @_;

      foreach my $key (CORE::keys %def) {
         $$self{"defmerge"}{"*"}{$key} = $def{$key}[1];
         $$self{"defmerge"}{"keep"}{$key} = "keep";
         $$self{"defmerge"}{"replace"}{$key} = "replace";
      }
   }

   sub _merge_allowed {
      my($type,$ordered,$val) = @_;

      my @tmp;
      if ($type eq "hash") {
         @tmp = @{ $def{"merge_hash"} };
      } elsif ($type eq "array") {
         if ($ordered) {
            @tmp = @{ $def{"merge_ol"} };
         } else {
            @tmp = @{ $def{"merge_ul"} };
         }
      } else {
         @tmp = @{ $def{"merge_scalar"} };
      }

      my $err = shift(@tmp);
      my %tmp = map { $_,1 } @tmp;
      return 0  if (! exists $tmp{$val});
      return 1;
   }
}

###############################################################################
# GET_STRUCTURE
###############################################################################
# Retrieve structural information for a path. Makes use of the default
# structural information.

sub get_structure {
   my($self,$path,$info) = @_;
   $info = "type"  if (! defined $info  ||  ! $info);

   # Split the path so that we can convert all elements into "*" when
   # appropriate.

   my @path = $self->path($path);
   my @p    = ();
   my $p    = "/";
   return ""  if (! exists $$self{"struct"}{$p});

   while (@path) {
      my $ele = shift(@path);
      my $p1  = $self->path([@p,"*"]);
      my $p2  = $self->path([@p,$ele]);
      if (exists $$self{"struct"}{$p1}) {
         push(@p,"*");
         $p = $p1;
      } elsif (exists $$self{"struct"}{$p2}) {
         push(@p,$ele);
         $p = $p2;
      } else {
         return "";
      }
   }

   # Return the information about the path.

   return $$self{"struct"}{$p}{$info}  if (exists $$self{"struct"}{$p}{$info});
   return ""  if (! exists $$self{"struct"}{$p}{"type"});

   my $type = $$self{"struct"}{$p}{"type"};

   if      ($info eq "ordered") {
      return ""  unless ($type eq "array");
      return $$self{"defstruct"}{"ordered"};

   } elsif ($info eq "uniform") {
      if      ($type eq "hash") {
         return $$self{"defstruct"}{"uniform_hash"};
      } elsif ($type eq "array") {
         my $ordered = $self->get_structure($p,"ordered");
         if ($ordered) {
            return $$self{"defstruct"}{"uniform_ol"};
         } else {
            return 1;
         }

      } else {
         return "";
      }

   } elsif ($info eq "merge") {
      if ($type eq "array") {
         my $ordered = $self->get_structure($p,"ordered");
         if ($ordered) {
            return $$self{"defstruct"}{"merge_ol"};
         } else {
            return $$self{"defstruct"}{"merge_ul"};
         }

      } elsif ($type eq "hash") {
         return $$self{"defstruct"}{"merge_hash"};

      } else {
         return $$self{"defstruct"}{"merge_scalar"};
      }

   } else {
      return "";
   }
}

###############################################################################
# GET_MERGE
###############################################################################

sub get_merge {
   my($self,$path,$ruleset) = @_;
   $ruleset = "*"  if (! $ruleset);
   my @path = $self->path($path);
   $path    = $self->path(\@path);

   # Check ruleset

   return $$self{"merge"}{$ruleset}{$path}
     if (exists $$self{"merge"}{$ruleset}{$path});

   my $type    = $self->get_structure($path,"type");
   my $ordered = $self->get_structure($path,"ordered");

   if ($type eq "hash") {
      return $$self{"defmerge"}{$ruleset}{"merge_hash"}
        if (exists $$self{"defmerge"}{$ruleset}{"merge_hash"});

   } elsif ($type eq "array"  &&  $ordered) {
      return $$self{"defmerge"}{$ruleset}{"merge_ol"}
        if (exists $$self{"defmerge"}{$ruleset}{"merge_ol"});

   } elsif ($type eq "array") {
      return $$self{"defmerge"}{$ruleset}{"merge_ul"}
        if (exists $$self{"defmerge"}{$ruleset}{"merge_ul"});

   } elsif ($type eq "scalar"  ||  $type eq "other") {
      return $$self{"defmerge"}{$ruleset}{"merge_scalar"}
        if (exists $$self{"defmerge"}{$ruleset}{"merge_scalar"});

   } else {
      return "";
   }

   # Check "*" (this should always find something)

   $ruleset = "*";

   return $$self{"merge"}{$ruleset}{$path}
     if (exists $$self{"merge"}{$ruleset}{$path});

   if ($type eq "hash") {
      return $$self{"defmerge"}{$ruleset}{"merge_hash"};

   } elsif ($type eq "array"  &&  $ordered) {
      return $$self{"defmerge"}{$ruleset}{"merge_ol"};

   } elsif ($type eq "array") {
      return $$self{"defmerge"}{$ruleset}{"merge_ul"};

   } elsif ($type eq "scalar"  ||  $type eq "other") {
      return $$self{"defmerge"}{$ruleset}{"merge_scalar"};
   }
}

###############################################################################
# CHECK_STRUCTURE
###############################################################################
# This checks the structure of an NDS (and may update the structural
# information if appropriate).

sub check_structure {
   my($self,$nds,$new) = @_;
   return (0,"")  if (! $$self{"structure"});
   $new = 0  if (! $new);

   _check_structure($self,$nds,$new,());
}

sub _check_structure {
   my($self,$nds,$new,@path) = @_;
   return (0,"")  if (! defined $nds);
   my $path = $self->path([@path]);

   # Check to make sure that it's the correct type of data.

   my $type = $self->get_structure($path,"type");
   if ($type) {
      my $ref = lc(ref($nds));
      $ref    = "scalar"  if (! $ref);

      if      ($type eq "hash"  ||  $type eq "array"  ||  $type eq "scalar") {
         if ($ref ne $type) {
            _warn($self,
                  "[check_structure] Invalid type (expected $type, got $ref)");
            return (2,$path);
         }

      } elsif ($type eq "array/hash") {
         if ($ref ne "array"  &&  $ref ne "hash") {
            _warn($self,
                  "[check_structure] Invalid type (expected $type, got $ref)");
            return (2,$path);
         }
         $type = "";

      } elsif ($type eq "other") {
         if ($ref eq "scalar"  ||
             $ref eq "hash"    ||
             $ref eq "array") {
            _warn($self,
                  "[check_structure] Invalid type (expected $type, got $ref)");
            return (2,$path);
         }

      } elsif ($type eq "unknown") {
         $type = "";

      } else {
         die "[check_structure] Impossible error: $type";
      }
   }

   if (! $type) {
      if ($new) {
         $type = lc(ref($nds));
         if (! $type) {
            _set_structure_path($self,"type","scalar",$path);
         } elsif ($type eq "hash"  ||
                  $type eq "array") {
            _set_structure_path($self,"type",$type,$path);
         } else {
            _set_structure_path($self,"type","other",$path);
         }

      } else {
         _warn($self,
               "[check_structure] New structure not allowed");
         return (1,$path);
      }
   }

   return (0,"") unless ($type eq "array"  ||  $type eq "hash");

   # Recurse into hashes.

   my $uniform = $self->get_structure($path,"uniform");
   if ($type eq "hash") {
      foreach my $key (CORE::keys %$nds) {
         my $val = $$nds{$key};
         if ($uniform) {
            my($err,$p) = _check_structure($self,$val,$new,@path,"*");
            return($err,$p)  if ($err);
         } else {
            my($err,$p) = _check_structure($self,$val,$new,@path,$key);
            return($err,$p)  if ($err);
         }
      }
      return (0,"");
   }

   # Recurse into arrays

   for (my $i=0; $i<=$#$nds; $i++) {
      my $val = $$nds[$i];
      if ($uniform) {
         my($err,$p) = _check_structure($self,$val,$new,@path,"*");
         return($err,$p)  if ($err);
      } else {
         my($err,$p) = _check_structure($self,$val,$new,@path,$i);
         return($err,$p)  if ($err);
      }
   }

   return (0,"")
}

###############################################################################
# MERGE_PATH
###############################################################################

sub merge_path {
   my($self,$nds,$val,$path,@args) = @_;

   my @path  = $self->path($path);
   $path     = $self->path(\@path);

   return merge($self,$nds,$val,@args)  if (! @path);

   #
   # Get nds by reference or name
   #

   if (! ref($nds)) {
      $nds = $self->nds($nds);
      if (! defined($nds)) {
         _warn($self,"[merge_path] NDS undefined: $nds");
         return 1;
      }
   }

   #
   # Parse ruleset and new arguments
   #

   my ($ruleset,$new);
   if (! @args) {
      $ruleset = "*";
      $new     = 0;

   } elsif ($#args == 0) {
      if ($args[0] eq "0"  ||  $args[0] eq "1") {
         $ruleset = "*";
         $new     = $args[0];
      } else {
         $ruleset = $args[0];
         $new     = 0;
      }

   } elsif ($#args == 1) {
      $ruleset = $args[0];
      $ruleset = $args[1];

   } else {
      die "[merge_path] Unknown argument list";
   }

   #
   # Check structure
   #

   my ($err,$v) = $self->check_structure($nds,$new);
   return 2  if ($err);

   ($err,$v) = _check_structure($self,$val,$new,@path);
   return 3  if ($err);

   #
   # Get the NDS stored at the path.
   #

   my $ele     = pop(@path);
   $nds        = _merge_path_nds($self,$nds,[],@path);

   #
   # Merge in the value
   #

   if (ref($nds) eq "HASH") {
      $$nds{$ele} = _merge($self,$$nds{$ele},$val,[@path,$ele],$ruleset);

   } elsif (ref($nds) eq "ARRAY") {
      $$nds[$ele] = _merge($self,$$nds[$ele],$val,[@path,$ele],$ruleset);
   }
   return 0;
}

# This returns the NDS stored at @path in $nds. $pathref is the path
# of $nds with respect to the main NDS structure.
#
# Since we removed the last element of the path in the merge_path
# method, this can ONLY be called with hash/array structures.
#
sub _merge_path_nds {
   my($self,$nds,$pathref,@path) = @_;
   return $nds  if (! @path);
   my($ele) = shift(@path);

   # Easy case: return an existing element

   if (ref($nds) eq "HASH") {
      if (exists $$nds{$ele}) {
         return _merge_path_nds($self,$$nds{$ele},[@$pathref,$ele],@path);
      }

   } else {
      if (defined $$nds[$ele]) {
         return _merge_path_nds($self,$$nds[$ele],[@$pathref,$ele],@path);
      }
   }

   # Hard case: create new structure

   my $type = $self->structure([@$pathref,$ele]);
   my $new;
   if ($type eq "hash") {
      $new = {};
   } else {
      $new = [];
   }

   if (ref($nds) eq "HASH") {
      $$nds{$ele} = $new;
      return _merge_path_nds($self,$$nds{$ele},[@$pathref,$ele],@path);

   } else {
      $$nds[$ele] = $new;
      return _merge_path_nds($self,$$nds[$ele],[@$pathref,$ele],@path);
   }
}

###############################################################################
# ERASE
###############################################################################
# This removes a path from an NDS based on the structural information.
# Hash elements are deleted, ordered elements are cleared, unordered
# elements are deleted.

sub erase {
   my($self,$nds,$path) = @_;

   #
   # Get the NDS
   #

   if (! ref($nds)) {
      $nds = $self->nds($nds);
      if (! defined($nds)) {
         _warn($self,"[erase] NDS undefined: $nds");
         return 1;
      }
   }

   #
   # If $path not passed in, clear the entire NDS
   #

   my(@path) = $self->path($path);
   if (! @path) {
      if (ref($nds) eq "HASH") {
         %$nds = ();
      } elsif (ref($nds) eq "ARRAY") {
         @$nds = ();
      }
      return 0;
   }

   #
   # Get the parent of $path
   #

   my $ele = pop(@path);
   my($valid,$where);
   ($valid,$nds,$where) = $self->valid($nds,[@path]);
   return 2  if (! $valid);

   #
   # Delete the element
   #

   if (ref($nds) eq "HASH") {
      if (exists $$nds{$ele}) {
         delete $$nds{$ele};
      } else {
         return 2;
      }

   } else {
      my $ordered = $self->get_structure([@path],"ordered");
      if ($ordered) {
         if (defined $$nds[$ele]) {
            $$nds[$ele] = undef;
         } else {
            return 2;
         }
      } else {
         if (defined $$nds[$ele]) {
            splice(@$nds,$ele,1);
         } else {
            return 2;
         }
      }
   }

   return 0;
}

###############################################################################
# IDENTICAL, CONTAINS
###############################################################################

sub identical {
   my($self,$nds1,$nds2,@args) = @_;
   return _identical_contains($self,$nds1,$nds2,1,@args);
}

sub contains {
   my($self,$nds1,$nds2,@args) = @_;
   return _identical_contains($self,$nds1,$nds2,0,@args);
}

sub _identical_contains {
   my($self,$nds1,$nds2,$identical,@args) = @_;

   #
   # Parse $new and $path
   #

   my($new,$path);
   if (! @args) {
      $new  = 0;
      $path = "";
   } elsif ($#args == 0) {
      if ($args[0] eq "0"  ||  $args[0] eq "1") {
         $new  = $args[0];
         $path = "";
      } else {
         $new  = 0;
         $path = $args[0];
      }
   } elsif ($#args == 1) {
      $new  = $args[0];
      $path = $args[1];
   } else {
      die "[identical/contains] invalid arguments";
   }

   #
   # Get nds1 and nds2 by reference or name
   #

   if (! ref($nds1)) {
      $nds1 = $self->nds($nds1);
      if (! defined($nds1)) {
         _warn($self,"[identical/contains] NDS1 undefined: $nds1");
         return 1;
      }
   }

   if (! ref($nds2)) {
      $nds2 = $self->nds($nds2);
      if (! defined($nds2)) {
         _warn($self,"[identical/contains] NDS2 undefined: $nds2");
         return 1;
      }
   }

   #
   # Check structure
   #

   my ($err,$val) = $self->check_structure($nds1,$new);
   return undef  if ($err);
   ($err,$val) = $self->check_structure($nds2,$new);
   return undef  if ($err);

   #
   # Handle $path
   #

   my (@path);
   if ($path) {
      my($valid,$where);
      ($valid,$nds1,$where) = $self->valid($nds1,$path);
      return undef  if (! $valid);

      ($valid,$nds2,$where) = $self->valid($nds2,$path);
      return undef  if (! $valid);

      @path = $self->path($path);
      $path = $self->path($path);
   }

   #
   # Recurse through the structure and create a hash of PATH => DESC
   # for every non-empty scalar.
   #

   my(%scalar1,%scalar2);
   _ic_scalars($self,$nds1,\%scalar1,[@path],[@path]);
   _ic_scalars($self,$nds2,\%scalar2,[@path],[@path]);

   #
   # One trivial case... if %scalar2 is bigger than %scalar1, it isn't
   # contained in it. If they are not equal in size, they can't be
   # identical.
   #

   my @k1 = CORE::keys %scalar1;
   my @k2 = CORE::keys %scalar2;
   if ($identical) {
      return 0  if ($#k1 != $#k2);
   } else {
      return 0  if ($#k1 < $#k2);
   }

   #
   # Get a hash of PATH => 1 for every PATH which contains an
   # unordered list index of the form _ul_i .
   #

   my(%ul1,%ul2);
   _ic_ul($self,\%scalar1,\%ul1);
   _ic_ul($self,\%scalar2,\%ul2);

   #
   # Do the easy part... elements with no unordered lists. All in %scalar2
   # must be in %scalar1. Also, for identical tests, all in %scalar1 must
   # be in %scalar2.
   #

   foreach my $path (@k2) {
      next  if (exists $ul2{$path});
      if (exists $scalar1{$path}  &&
          $scalar1{$path}{"val"} eq $scalar2{$path}{"val"}) {
         delete $scalar1{$path};
         delete $scalar2{$path};
         next;
      } else {
         return 0;
      }
   }

   if ($identical) {
      foreach my $path (@k1) {
         next  if (exists $ul1{$path});
         if (exists $scalar2{$path}  &&
             $scalar1{$path}{"val"} eq $scalar2{$path}{"val"}) {
            delete $scalar1{$path};
            delete $scalar2{$path};
            next;
         } else {
            return 0;
         }
      }
   } else {
      # If we're doing "contains", remove all entries that have no unordered lists
      # that are left in %scalar1.
      foreach my $path (@k1) {
         next  if (exists $ul1{$path});
         delete $scalar1{$path};
      }
   }

   #
   # We're left only with elements containing unordered lists. Compare them.
   #







   #
   # We want to get a hash of all elements containing exactly the same
   # path elements (except for unordered list elements).
   #
   #    %scalar = ( PATH  => { val   => VAL,
   #                           p     => [ @PATH ],
   #                           mpath => MPATH
   #                         } )
   #    %mpath  = ( MPATH => [ PATH, PATH, ... ] )
   #
   # where:
   #
   #    PATH     : the full path to a scalar        /a/_ul_4/b/_ul_3)
   #    @PATH    : the split path                   a, _ul_4, b, _ul_3
   #    MPATH    : the modified path                /a/*/b/*
   #

   my(%mpath1,%mpath2);
   _ic_mpath(\%scalar1,\%mpath1);
   _ic_mpath(\%scalar2,\%mpath2);

   #
   # Compare each set of identically structured elements.
   #

   foreach my $key (CORE::keys %mpath1) {
      return 0  if (! exists $mpath2{$key});

      my @path1 = @{ $mpath1{$key} };
      my @path2 = @{ $mpath2{$key} };
      if ($identical) {
         return 0  if ($#path1 != $#path2);
      } else {
         return 0  if ($#path1 < $#path2);
      }

      #
      # Make a list of:
      #   @list = ( [X,Y,...], [VAL1, VAL2, ...], [] ... )
      # where X, Y, ..., are indices of the unordered lists elements
      # (except for the last one), VAL1, VAL2, ... are the values
      #

      %ul1 = ();
      %ul2 = ();


#       my $flag;
#       if ($identical) {
#          $flag = _ic_identical(\%scalar1,$mpath1{$key},\%scalar2,$mpath2{$key});
#       } else {
#          $flag = _ic_contains(\%scalar1,$mpath1{$key},\%scalar2,$mpath2{$key});
#       }
#       return 0  if (! $flag);

      delete $mpath1{$key};
      delete $mpath2{$key};
   }

   return 0  if (CORE::keys %mpath2);
   return 1;
}

# This creates a description of every path containing a scalar. The
# description includes the following:
#    { val    => VAL           the scalar at the path
#      mpath  => MPATH         a modified path (/a/_ul_1 instead of /a/1)
#      path   => [ @PATH ]     path in list format
#
# We have to keep two copies of the path... one with the actual path
# information:
#    /a/1/b
# and one with the modified path:
#    /a/_ul_1/b
#
sub _ic_scalars {
   my($self,$nds,$hashref,$mpath,$path) = @_;

   if (ref($nds) eq "HASH") {
      foreach my $key (CORE::keys %$nds) {
         _ic_scalars($self,$$nds{$key},$hashref,[@$mpath,$key],[@$path,$key]);
      }

   } elsif (ref($nds) eq "ARRAY") {
      my $ordered = $self->get_structure([@$path,0],"ordered");

      if ($ordered) {
         for (my $i=0; $i<=$#$nds; $i++) {
            _ic_scalars($self,$$nds[$i],$hashref,[@$mpath,$i],[@$path,$i]);
         }

      } else {
         for (my $i=0; $i<=$#$nds; $i++) {
            _ic_scalars($self,$$nds[$i],$hashref,[@$mpath,"_ul_$i"],[@$path,$i]);
         }
      }

   } elsif (! $self->empty($nds)) {
      my $p    = $self->path($path);
      my $mp   = $self->path($mpath);
      my @p    = $self->path($path);
      $$hashref{$p}{"val"}   = $nds;
      $$hashref{$p}{"mpath"} = $mp;
      $$hashref{$p}{"path"}  = [@p];
   }
}

# Check for every path which has the form _ul_I in it.
#
sub _ic_ul {
   my($self,$scalars,$uls) = @_;
   my $delim = $self->delim();

   foreach my $path (CORE::keys %$scalars) {
      my $mpath = $$scalars{$path}{"mpath"};
      next  unless ($mpath =~ /\Q$delim\E_ul_\d+(\Q$delim\E|$)/);
      $$uls{$path} = 1;
   }
}

# Takes every element in a %scalar hash and creates the %mpath hash.
#
sub _ic_mpath {
   my($scalar,$mpath) = @_;

   foreach my $path (CORE::keys %$scalar) {
      my $mp = $path;
      $mp    =~ s/_ul_\d+/\*/g;
      $$scalar{$path}{"mpath"} = $mp;
      if (exists $$mpath{$mp}) {
         push @{ $$mpath{$mp} },$path;
      } else {
         $$mpath{$mp} = [ $path ];
      }
   }
}

# Takes a path and returns a list of all keys in the hash $ele which have
# the exact same form. For this condition to hold true, all path elements
# have to be exactly the same except for unordered lists.

#      o  While this list contains elements:
#           Take the first one and match it to (.*)<<(i)>>(.*)
#           PATH1,ELE,PATH2 = ($1,$2,$3)
#           Here, PATH1 may contain other unordered element entries, but
#           PATH2 does not.
#
#           Find a list of all of the paths which start with PATH1<<i>>
#           Create a hash of all PATH2 => VAL
#           Assign a unique checksum based on the sorted key=>values
#           Replace PATH1/<<i>> with PATH1/CHECKSUM
#
#           Recreate the list of all PATHs still containing unordered
#           list elements
#         Done
#      o  Now, check to make sure that every PATH => VAL pair included
#         in one NDS is in both (identical) or the first (contains)


###############################################################################
###############################################################################

1;
# Local Variables:
# mode: cperl
# indent-tabs-mode: nil
# cperl-indent-level: 3
# cperl-continued-statement-offset: 2
# cperl-continued-brace-offset: 0
# cperl-brace-offset: 0
# cperl-brace-imaginary-offset: 0
# cperl-label-offset: -2
# End:
