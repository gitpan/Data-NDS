package Data::NDS;
# Copyright (c) 2008-2008 Sullivan Beck. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

########################################################################
# TODO
########################################################################

# Add validity tests for data
# see Data::Domain, Data::Validator

# Add subtract (to remove items in one NDS from another)
# see Data::Validate::XSD
# treats all lists as ordered... it's simply too complicated
# otherwise

# Add clean (to remove empty paths)
#    a hash key with a value of undef should be deleted
#    a list element with a value of undef should be deleted if unordered
#    a list consisting of only undefs should be deleted (and fix parent)
#    a hash with no keys should be deleted (and fix parent)

# Add ability to ignore structural information so that lists can
# be unordered and non-uniform ???

########################################################################

require 5.000;
use strict;
use Storable qw(dclone);
use Algorithm::Permute;
use IO::File;
use warnings;

use vars qw($VERSION);
$VERSION = "1.02";

use vars qw($_DBG $_DBG_INDENT $_DBG_OUTPUT $_DBG_FH $_DBG_POINT);
$_DBG        = 0;
$_DBG_INDENT = 0;
$_DBG_OUTPUT = "dbg.out";
$_DBG_FH     = ();
$_DBG_POINT  = 0;

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
#   ruleset   => { RULESET    => { def  => { ITEM => VAL },
#                                  path => { PATH => VAL } } }
#                                                        default and path
#                                                        specific ruleset
#                                                        merge methods
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
              "ruleset"   => {},
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
   return 3  if ($name eq "keep"     ||
                 $name eq "replace"  ||
                 $name eq "default"  ||
                 $name eq "override"
                );
   return 1  if ($name !~ /^[a-zA-Z0-9]+$/);
   return 2  if (exists $$self{"ruleset"}{$name});
   $$self{"ruleset"}{$name} = { "def"  => {},
                                "path" => {} };
   return 0;
}

sub ruleset_valid {
   my($self,$name) = @_;
   return 1  if (exists $$self{"ruleset"}{$name});
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

{
   my %path = ();

   sub path {
      my($self,$path) = @_;
      my $array       = wantarray;
      my($delim)      = $self->delim();

      if ($array) {
         return @$path            if (ref($path));
         return ()                if (! $path);
         return @{ $path{$path} } if (exists $path{$path});

         my @tmp      = split(/\Q$delim\E/,$path);
         shift(@tmp)  if (! defined($tmp[0])  ||  $tmp[0] eq "");
         $path{$path} = [ @tmp ];
         return @tmp;

      } else {
         if (! ref($path)) {
            return $delim         if (! $path);
            return $path;
         }
         return $delim . join($delim,@$path);
      }
   }
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
      delete $$self{"nds"}{$name}, return 1
        if (exists $$self{"nds"}{$name});
      return 0;
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

sub _nds {
   my($self,$nds) = @_;

   if (defined $nds  &&  exists $$self{"nds"}{$nds}) {
      return $$self{"nds"}{$nds};
   } else {
      return $nds;
   }
}

sub empty {
   my($self,$nds) = @_;
   $nds = _nds($self,$nds);
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

   } else {
      return 0;
   }
}

###############################################################################
# KEYS, VALUES
###############################################################################

sub keys {
   my($self,$nds,$path) = @_;
   $nds = _nds($self,$nds);
   my($valid,$val) = $self->valid($nds,$path);

   return undef  if (! $valid);

   if (! ref($val)) {
      return ();

   } elsif (ref($val) eq "ARRAY") {
      my(@ret);
      foreach my $i (0..$#$val) {
         push(@ret,$i)  if (! _empty($$val[$i]));
      }
      return @ret;

   } elsif (ref($val) eq "HASH") {
      my(@ret);
      foreach my $key (sort(CORE::keys %$val)) {
         push(@ret,$key)  if (! _empty($$val{$key}));
      }
      return @ret;

   } else {
      return undef;
   }
}

sub values {
   my($self,$nds,$path) = @_;
   $nds = _nds($self,$nds);
   my($valid,$val) = $self->valid($nds,$path);

   return undef  if (! $valid);

   if (! ref($val)) {
      return ($val);

   } elsif (ref($val) eq "ARRAY") {
      my(@ret);
      foreach my $i (0..$#$val) {
         push(@ret,$$val[$i])  if (! _empty($$val[$i]));
      }
      return @ret;

   } elsif (ref($val) eq "HASH") {
      my(@ret);
      foreach my $key (sort(CORE::keys %$val)) {
         push(@ret,$$val{$key})  if (! _empty($$val{$key}));
      }
      return @ret;

   } else {
      return undef;
   }
}

###############################################################################
# VALID/VALUE
###############################################################################
# Checks to see if a path is valid in an NDS

sub valid {
   my($self,$nds,$path) = @_;
   $nds = _nds($self,$nds);
   my($delim) = $self->delim();
   my @path   = $self->path($path);

   if (! ref($nds)) {
      return (0,-1);
   }

   return _valid($nds,$delim,"",@path);
}

sub value {
   my($valid,$val) = valid(@_);
   return undef  if (! $valid);
   return $val;
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
   $path = ($path ? join($delim,$path,$p) : "$delim$p");

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
   return  if (! defined $nds2);

   #
   # Get nds1 and nds2 by reference or name
   #

   $nds1 = _nds($self,$nds1);
   if (! defined($nds1)) {
      _warn($self,"[merge] NDS1 undefined: $nds1");
      return 1;
   }

   $nds2 = _nds($self,$nds2);
   if (! defined($nds2)) {
      _warn($self,"[merge] NDS2 undefined: $nds2");
      return 1;
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
      $new     = $args[1];

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

   my $tmp = _merge($self,$nds1,$nds2,[],$ruleset);
   if (ref($nds1) eq "HASH") {
      %$nds1 = %$tmp;
   } elsif (ref($nds1) eq "ARRAY") {
      @$nds1 = @$tmp;
   } else {
      return 5;
   }
   return 0;
}

sub _merge {
   my($self,$nds1,$nds2,$pathref,$ruleset) = @_;
   my $path = $self->path($pathref);

   #
   # If $nds2 is empty, we'll always return whatever $nds1 is.
   # If $nds1 is empty or "", we'll always return a copy of whatever $nds2 is.
   #

   return $nds1  if ($self->empty($nds2));
   if ($self->empty($nds1)  ||
       (! ref($nds1)  &&  $nds1 eq "")) {
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

      #
      # If $val2 is empty, we'll keep $val1
      # If $val1 is empty or "", we'll always set it to $val2
      #

      next  if ($self->empty($$val2{$key}));

      if (! exists $$val1{$key}  ||
          $self->empty($$val1{$key})  ||
          (! ref($$val1{$key})  &&  $$val1{$key} eq "")) {
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
      # empty/'' *          val1[i] = val2[i]
      # *        *          recurse into (including scalars)

      if ($self->empty($$val2[$i])) {
         next;

      } elsif ($self->empty($$val1[$i])  ||
               (! ref($$val1[$i])  &&  $$val1[$i] eq "")) {
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

   if (exists $$self{"ruleset"}{$ruleset}{"path"}{$path}) {
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

   $$self{"ruleset"}{$ruleset}{"path"}{$path} = $method;
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
      $$self{"ruleset"}{$ruleset}{"def"}{$item} = $val;
      return 0;
   }

   # Set up the default merge:
   sub _merge_defaults {
      my($self) = @_;

      foreach my $key (CORE::keys %def) {
         $$self{"ruleset"}{"*"}{"def"}{$key} = $def{$key}[1];
      }

      $$self{"ruleset"}{"keep"}{"def"} =
        { "merge_hash"   => "keep",
          "merge_ol"     => "keep",
          "merge_ul"     => "keep",
          "merge_scalar" => "keep" };

      $$self{"ruleset"}{"replace"}{"def"} =
        { "merge_hash"   => "replace",
          "merge_ol"     => "replace",
          "merge_ul"     => "replace",
          "merge_scalar" => "replace" };

      $$self{"ruleset"}{"default"}{"def"} =
        { "merge_hash"   => "merge",
          "merge_ol"     => "merge",
          "merge_ul"     => "keep",
          "merge_scalar" => "keep" };

      $$self{"ruleset"}{"override"}{"def"} =
        { "merge_hash"   => "merge",
          "merge_ol"     => "merge",
          "merge_ul"     => "replace",
          "merge_scalar" => "replace" };

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

   return $$self{"ruleset"}{$ruleset}{"path"}{$path}
     if (exists $$self{"ruleset"}{$ruleset}{"path"}{$path});

   my $type    = $self->get_structure($path,"type");
   my $ordered = $self->get_structure($path,"ordered");

   if ($type eq "hash") {
      return $$self{"ruleset"}{$ruleset}{"def"}{"merge_hash"}
        if (exists $$self{"ruleset"}{$ruleset}{"def"}{"merge_hash"});

   } elsif ($type eq "array"  &&  $ordered) {
      return $$self{"ruleset"}{$ruleset}{"def"}{"merge_ol"}
        if (exists $$self{"ruleset"}{$ruleset}{"def"}{"merge_ol"});

   } elsif ($type eq "array") {
      return $$self{"ruleset"}{$ruleset}{"def"}{"merge_ul"}
        if (exists $$self{"ruleset"}{$ruleset}{"def"}{"merge_ul"});

   } elsif ($type eq "scalar"  ||  $type eq "other") {
      return $$self{"ruleset"}{$ruleset}{"def"}{"merge_scalar"}
        if (exists $$self{"ruleset"}{$ruleset}{"def"}{"merge_scalar"});

   } else {
      return "";
   }

   # Check "*" (this should always find something)

   $ruleset = "*";

   return $$self{"ruleset"}{$ruleset}{"path"}{$path}
     if (exists $$self{"ruleset"}{$ruleset}{"path"}{$path});

   if ($type eq "hash") {
      return $$self{"ruleset"}{$ruleset}{"def"}{"merge_hash"};

   } elsif ($type eq "array"  &&  $ordered) {
      return $$self{"ruleset"}{$ruleset}{"def"}{"merge_ol"};

   } elsif ($type eq "array") {
      return $$self{"ruleset"}{$ruleset}{"def"}{"merge_ul"};

   } elsif ($type eq "scalar"  ||  $type eq "other") {
      return $$self{"ruleset"}{$ruleset}{"def"}{"merge_scalar"};
   }
}

###############################################################################
# CHECK_STRUCTURE
###############################################################################
# This checks the structure of an NDS (and may update the structural
# information if appropriate).

sub check_structure {
   my($self,$nds,$new) = @_;
   $nds = _nds($self,$nds);
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

   $nds = _nds($self,$nds);
   if (! defined($nds)) {
      _warn($self,"[merge_path] NDS undefined: $nds");
      return 1;
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
      $new     = $args[1];

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

   $nds = _nds($self,$nds);
   if (! defined($nds)) {
      _warn($self,"[erase] NDS undefined: $nds");
      return 1;
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
   $nds1 = _nds($self,$nds1);
   $nds2 = _nds($self,$nds2);
   _DBG_begin("Identical");

   my $flag = _identical_contains($self,$nds1,$nds2,1,@args);

   _DBG_end($flag);
   return $flag;
}

sub contains {
   my($self,$nds1,$nds2,@args) = @_;
   $nds1 = _nds($self,$nds1);
   $nds2 = _nds($self,$nds2);
   _DBG_begin("Contains");

   my $flag = _identical_contains($self,$nds1,$nds2,0,@args);

   _DBG_end($flag);
   return $flag;
}

sub _identical_contains {
   my($self,$nds1,$nds2,$identical,@args) = @_;
   _DBG_enter("_identical_contains");

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

   if (! defined($nds1)) {
      _warn($self,"[identical/contains] NDS1 undefined: $nds1");
      _DBG_leave("ERROR NDS1 undefined");
      return 1;
   }

   if (! defined($nds2)) {
      _warn($self,"[identical/contains] NDS2 undefined: $nds2");
      _DBG_leave("ERROR NDS2 undefined");
      return 1;
   }

   #
   # Check structure
   #

   my ($err,$val) = $self->check_structure($nds1,$new);
   if ($err) {
      _DBG_leave("ERROR check_structure 1");
      return undef;
   }

   ($err,$val) = $self->check_structure($nds2,$new);
   if ($err) {
      _DBG_leave("ERROR check_structure 2");
      return undef;
   }

   #
   # Handle $path
   #

   my (@path);
   if ($path) {
      my($valid,$where);
      ($valid,$nds1,$where) = $self->valid($nds1,$path);
      if (! $valid) {
         _DBG_leave("ERROR invalid 1");
         return undef;
      }

      ($valid,$nds2,$where) = $self->valid($nds2,$path);
      if (! $valid) {
         _DBG_leave("ERROR invalid 2");
         return undef;
      }

      @path = $self->path($path);
      $path = $self->path($path);
   }

   #
   # We will now recurse through the data structure and get an
   # mpath description.
   #
   # An mpath description will be stored as:
   #   %desc = ( MPATH  => DESC )
   #
   # An MPATH is related to a PATH, except that every path element that
   # contains an index for an unordered list is transformed to illustrate
   # this. For example, for the path:
   #   /foo/1/bar/2
   # the mpath is:
   #   /foo/_ul_1/bar/_ul_2
   # (assuming that the 2nd and 4th elements are indices in unorderd
   #lists).
   #

   my(%desc1,%desc2);
   _ic_desc($self,$nds1,\%desc1,[@path],[@path],0,$self->delim());
   _ic_desc($self,$nds2,\%desc2,[@path],[@path],0,$self->delim());

   #
   # Now check these description hashes to see if they are identical
   # (or contained). This is done recusively.
   #

   my $flag = _ic_compare($self,\%desc1,\%desc2,$identical,$self->delim());
   _DBG_leave($flag);
   return $flag;
}

# This compares all elements of two description hashes to see if
# they are identical, or if the second is contained in the first.
#
sub _ic_compare {
   my($self,$desc1,$desc2,$identical,$delim) = @_;
   _DBG_enter("_ic_compare");
   if ($_DBG) {
      _DBG_line("DESC1 =");
      foreach my $mpath (sort(CORE::keys %$desc1)) {
         my $val = $$desc1{$mpath}{"val"} .
           "  [" . join(" ",@{ $$desc1{$mpath}{"meles"} }) . "]";
         _DBG_line("   $mpath\t= $val");
      }
      _DBG_line("DESC2 =");
      foreach my $mpath (sort(CORE::keys %$desc2)) {
         my $val = $$desc2{$mpath}{"val"} .
           "  [" . join(" ",@{ $$desc2{$mpath}{"meles"} }) . "]";
         _DBG_line("   $mpath\t= $val");
      }
   }

   #
   # Separate %desc into two sections. Move everything containing any
   # unordered list induces to %ul.  %desc will end up containing
   # everything else (which is handled very simply).
   #

   my(%ul1,%ul2);
   _ic_ul($desc1,\%ul1);
   _ic_ul($desc2,\%ul2);

   #
   # One trivial case... if %desc2 is bigger than %desc1, (or %ul2
   # is bigger than %ul1) it isn't contained in it. If they are not
   # equal in size, they can't be identical.
   #

   my @d1 = CORE::keys %$desc1;
   my @d2 = CORE::keys %$desc2;
   my @u1 = CORE::keys %ul1;
   my @u2 = CORE::keys %ul2;
   if ($identical) {
      _DBG_leave("Not equal"), return 0  if ($#d1 != $#d2  ||
                                            $#u1 != $#u2);
   } else {
      _DBG_leave("Bigger"),    return 0  if ($#d1 < $#d2  ||
                                            $#u1 < $#u2);
   }

   #
   # Do the easy part... elements with no unordered lists. All in
   # %desc2 must be in %desc1. For identical tests, nothing else
   # can exist.
   #

   foreach my $mpath (@d2) {
      if (exists $$desc1{$mpath}  &&
          $$desc1{$mpath}{"val"} eq $$desc2{$mpath}{"val"}) {
         delete $$desc1{$mpath};
         delete $$desc2{$mpath};
         next;
      } else {
         _DBG_leave("Desc differs");
         return 0;
      }
   }

   @d1 = CORE::keys %$desc1;
   _DBG_leave("Desc not equal"), return 0  if ($identical  &&  @d1);

   #
   # Now do elements containing unordered lists.
   #

   if ($#u2 == -1) {
      _DBG_leave("UL not identical"), return 0  if ($identical  &&  $#u1 > -1);
      _DBG_leave(1);
      return 1;
   }
   my $flag = _ic_compare_ul($self,\%ul1,\%ul2,$identical,$delim);
   _DBG_leave($flag);
   return $flag;
}

# This recurses through %ul1 and %ul2 to try all possible combinations
# of indices for unordered elements. At every level of recusion, we do
# the left-most set of indices.
#
sub _ic_compare_ul {
   my($self,$ul1,$ul2,$identical,$delim) = @_;
   _DBG_enter("_ic_compare_ul");
   if ($_DBG) {
      _DBG_line("UL1 =");
      foreach my $mpath (sort(CORE::keys %$ul1)) {
         my $val = $$ul1{$mpath}{"val"} .
           "  [" . join(" ",@{ $$ul1{$mpath}{"meles"} }) . "]";
         _DBG_line("   $mpath\t= $val");
      }
      _DBG_line("UL2 =");
      foreach my $mpath (sort(CORE::keys %$ul2)) {
         my $val = $$ul2{$mpath}{"val"} .
           "  [" . join(" ",@{ $$ul2{$mpath}{"meles"} }) . "]";
         _DBG_line("   $mpath\t= $val");
      }
   }

   #
   # We need to get a list of all similar mpaths up to this level.
   # To determine if two mpaths are similar, look at the first element
   # in @meles in each.
   #
   # If both are unordered list indices (not necessarily identical) or
   # both are NOT unordered list indices and are identical, then they
   # are similar.
   #

 COMPARE: while (1) {
      my @mpath2 = CORE::keys %$ul2;
      last COMPARE  if (! @mpath2);

      #
      # Look at the first element in @meles in one of the $ul entries.
      # It will either be an unordered list index or a set of 1 or more
      # path elements which do NOT contain unordered list indices.
      #

      my $mpath = $mpath2[0];
      my $mele  = $$ul2{$mpath}{"meles"}[0];

      if ($mele =~ /^_ul_/) {

         # Get a list of all elements with a first $mele an _ul_ and
         # move them to a temporary description hash.

         my(%tmp1,%tmp2);
         _ic_ul2desc($ul1,\%tmp1,$mele,1);
         _ic_ul2desc($ul2,\%tmp2,$mele,1);

         # Find the number of unique $mele in %ul1 and %ul2 .  If
         # the number in %ul2 is greater, it can't be contained. It
         # can't be identical unless the two numbers are the same.

         my $max1 = _ic_max_idx(\%tmp1);
         my $max2 = _ic_max_idx(\%tmp2);

         _DBG_leave("Bigger"),    return 0  if ($max2 > $max1);
         _DBG_leave("Not equal"), return 0  if ($identical  &&  $max1 != $max2);

         # Copy all elements from %ul1 to %desc1, but change them
         # from _ul_I to J (where J is 0..MAX)
         #
         # After we set a combination, we need to reset MELES.

         my $desc1 = {};
         _ic_permutation(\%tmp1,$desc1,(0..$max1));
         foreach my $mp (CORE::keys %$desc1) {
            $$desc1{$mp}{"meles"} = _ic_mpath2meles($self,$mp,$delim);
         }

         # Try every combination of the elements in %ul2 setting
         # _ul_I to J (where J is 1..MAX and MAX comes from %ul1)

         # For some reason (a bug in Algorigthm::Permute???) the
         # recursion here is causing unpredictable behaviors. We'll
         # get a list of all combinations and store them here to
         # avoid the problem.
         my $p = new Algorithm::Permute([0..$max1],$max2+1);

         while (my(@idx) = $p->next) {

            my $d1 = {};
            my $d2 = {};
            $d1 = dclone($desc1);
            _ic_permutation(\%tmp2,$d2,@idx);
            foreach my $mp (CORE::keys %$d2) {
               $$d2{$mp}{"meles"} = _ic_mpath2meles($self,$mp,$delim);
            }

            next COMPARE
              if (_ic_compare($self,$d1,$d2,$identical,$delim));
         }

         _DBG_leave("Unordered list fails");
         return 0;

      } else {

         #
         # Not an unordered list.
         #
         # Go through all %ul mpaths and take all elements which
         # have the same leading $mele and move them to a new
         # %desc hash. Then compare the two %desc hashes.
         #

         my(%desc1,%desc2);
         _ic_ul2desc($ul1,\%desc1,$mele,0);
         _ic_ul2desc($ul2,\%desc2,$mele,0);

         _DBG_leave("Desc fails"), return 0
           if (! _ic_compare($self,\%desc1,\%desc2,$identical,$delim));

      }
   }

   my @mpath1 = CORE::keys %$ul1;
   _DBG_leave("Remaining items fail"), return 0  if (@mpath1  &&  $identical);
   _DBG_leave(1);
   return 1;
}

# This recurses through a data structure and creates a description of
# every path containing a scalar. The description is a hash of the
# form:
#
# %desc =
#    ( MPATH =>
#       { val    => VAL           the scalar at the path
#         path   => PATH          the actual path         /a/1
#         mpath  => MPATH         the modified path       /a/_ul_1
#         ul     => N             the number of unordered indices in mpath
#         meles  => MELES         a list of modified elements (see below)
#         mele   => MELE          the part of MELES currently being examined
#       }
#    )
#
# Ths MELES list is a list of "elements" where can be combined to form the
# mpath (using the delimiter). Each element of MELES is either an index of
# an unordered list or all adjacent path elements which are not unordered
# list indices. For example, the mpath:
#     /a/_ul_1/b/c/_ul_3/_ul_4
# would become the following MELES
#     [ a, _ul_1, b/c, _ul_3, _ul_4 ]
#
# We'll pass both the path and mpath (as listrefs) as arguments as well
# as a flag whether or not we've had any unordered elements in the path
# to this point.
#
sub _ic_desc {
   my($self,$nds,$desc,$mpath,$path,$ul,$delim) = @_;

   if (ref($nds) eq "HASH") {
      foreach my $key (CORE::keys %$nds) {
         _ic_desc($self,$$nds{$key},$desc,[@$mpath,$key],[@$path,$key],$ul,
                  $delim);
      }

   } elsif (ref($nds) eq "ARRAY") {
      my $ordered = $self->get_structure([@$path,0],"ordered");

      if ($ordered) {
         for (my $i=0; $i<=$#$nds; $i++) {
            _ic_desc($self,$$nds[$i],$desc,[@$mpath,$i],[@$path,$i],$ul,$delim);
         }

      } else {
         for (my $i=0; $i<=$#$nds; $i++) {
            _ic_desc($self,$$nds[$i],$desc,[@$mpath,"_ul_$i"],[@$path,$i],$ul+1,
                     $delim);
         }
      }

   } elsif (! $self->empty($nds)) {
      my $p     = $self->path($path);
      my $mp    = $self->path($mpath);

      $$desc{$mp} = { "val"   => $nds,
                      "path"  => $p,
                      "mpath" => $mp,
                      "meles" => _ic_mpath2meles($self,$mpath,$delim),
                      "ul"    => $ul
                    };
   }
}

# Move all elements from %desc to %ul which have unordered list elements
# in them.
#
sub _ic_ul {
   my($desc,$ul) = @_;

   foreach my $mpath (CORE::keys %$desc) {
      if ($$desc{$mpath}{"ul"}) {
         $$ul{$mpath} = $$desc{$mpath};
         delete $$desc{$mpath};
      }
   }
}

# This moves moves all elements from %ul to %desc which have the given
# first element in @meles.
#
# $mele can be an unordered list element (in which case all elements
# with unordered list elements are moved) or not (in which case, all
# elements with the same first $mele are moved).
#
sub _ic_ul2desc {
   my($ul,$desc,$mele,$isul) = @_;

   foreach my $mpath (CORE::keys %$ul) {
      if ( ($isul    &&  $$ul{$mpath}{"meles"}[0] =~ /^_ul_/)  ||
           (! $isul  &&  $$ul{$mpath}{"meles"}[0] eq $mele) ) {

         # Move the element to %desc

         $$desc{$mpath} = $$ul{$mpath};
         delete $$ul{$mpath};

         # Fix @meles accordingly

         my @meles = @{ $$desc{$mpath}{"meles"} };
         my $m = shift(@meles);

         $$desc{$mpath}{"meles"} = [ @meles ];
         $$desc{$mpath}{"mele"} = $m;
      }
   }
}

# This goes through a description hash (%desc) and sets the "meles" value
# for each element.
#
sub _ic_mpath2meles {
   my($self,$mpath,$delim) = @_;
   my(@mpath) = $self->path($mpath);

   my @meles  = ();
   my $tmp    = "";
   foreach my $mele (@mpath) {
      if ($mele =~ /^_ul_/) {
         if ($tmp) {
            push(@meles,$tmp);
            $tmp = "";
         }
         push(@meles,$mele);
      } else {
         if ($tmp) {
            $tmp .= "$delim$mele";
         } else {
            $tmp = $mele;
         }
      }
   }
   if ($tmp) {
      push(@meles,$tmp);
   }
   return [ @meles ];
}

# This goes through all of the elements in a %desc hash. All of them should
# have a descriptor "mele" which is an unordered list index in the form
# _ul_I . Find out how many unique ones there are.
#
sub _ic_max_idx {
   my($desc) = @_;

   my %tmp;
   foreach my $mpath (CORE::keys %$desc) {
      my $mele = $$desc{$mpath}{"mele"};
      $tmp{$mele} = 1;
   }

   my @tmp = CORE::keys %tmp;
   return $#tmp;
}

# This copies all elements from one description hash (%tmpdesc) to a final
# description hash (%desc). Along the way, it substitutes all leading
# unordered list indices (_ul_i) with the current permutation index.
#
# So if the list of indices (@idx) is (0,2,1) and the current list of
# unorderd indices is (_ul_0, _ul_1, _ul_2), then every element containing
# a leading _ul_1 in the mpath will be modified and that element will be
# replaced by "2".
#
sub _ic_permutation {
   my($tmpdesc,$desc,@idx) = @_;

   # Get a sorted list of all unordered indices:
   #   (_ul_0, _ul_1, _ul_2)

   my(%tmp);
   foreach my $mpath (CORE::keys %$tmpdesc) {
      my $mele    = $$tmpdesc{$mpath}{"mele"};
      $tmp{$mele} = 1;
   }
   my @tmp = sort(CORE::keys %tmp);

   # Create a hash of unordered list indices and their
   # replacement:
   #   _ul_0  => 0
   #   _ul_1  => 2
   #   _ul_2  => 1

   %tmp = ();
   while (@tmp) {
      my($ul)  = shift(@tmp);
      my($idx) = shift(@idx);
      $tmp{$ul} = $idx;
   }

   # Copy the element from %tmpdesc to %desc
   #    Substitute the unordered list index with the permutation index
   #    Clear "mele" value
   #    Decrement "ul" value

   foreach my $mpath (CORE::keys %$tmpdesc) {
      my $mele  = $$tmpdesc{$mpath}{"mele"};
      my $idx   = $tmp{$mele};
      my $newmp = $mpath;
      $newmp    =~ s/$mele/$idx/;

      $$desc{$newmp}          = dclone($$tmpdesc{$mpath});
      $$desc{$newmp}{"mpath"} = $newmp;
      $$desc{$newmp}{"mele"}  = "";
      $$desc{$newmp}{"ul"}--;
   }
}

###############################################################################
# WHICH
###############################################################################

sub which {
   my($self,$nds,@crit) = @_;
   $nds = _nds($self,$nds);

   if (! @crit) {
      my %ret;
      _which_scalar($self,$nds,\%ret,{},[]);
      return %ret;
   } else {
      my(@re,%vals,%ret);
      foreach my $crit (@crit) {
         if (ref($crit) eq "Regexp") {
            push(@re,$crit);
         } else {
            $vals{$crit} = 1;
         }
      }
      _which_scalar($self,$nds,\%ret,\%vals,\@re);
      return %ret;
   }
}

# Sets %ret to be a hash of PATH => VAL for every path which
# passes one of the criteria.
#
# If %vals is not empty, a path passes if it's value is any of
# the keys in %vals.
#
# If @re is not empty, a path passes if it matches any of the
# regular expressions in @re.
#
sub _which_scalar {
   my($self,$nds,$ret,$vals,$re,@path) = @_;

   if (ref($nds) eq "HASH") {
      foreach my $key (CORE::keys %$nds) {
         _which_scalar($self,$$nds{$key},$ret,$vals,$re,@path,$key);
      }

   } elsif (ref($nds) eq "ARRAY") {
      foreach (my $i = 0; $i <= $#$nds; $i++) {
         _which_scalar($self,$$nds[$i],$ret,$vals,$re,@path,$i);
      }

   } else {
      my $path = $self->path([@path]);
      my $crit = 0;

      if (CORE::keys %$vals) {
         $crit = 1;
         if (exists $$vals{$nds}) {
            $$ret{$path} = $nds;
            return;
         }
      }

      if (@$re) {
         $crit = 1;
         foreach my $re (@$re) {
            if ($nds =~ $re) {
               $$ret{$path} = $nds;
               return;
            }
         }
      }

      return  if ($crit);

      # No criteria passed in
      $$ret{$path} = $nds   if (defined $nds);
      return;
   }
}

###############################################################################
# DEBUG ROUTINES
###############################################################################

# Begin a new debugging session.
sub _DBG_begin {
   my($function) = @_;
   return  unless ($_DBG);

   $_DBG_FH = new IO::File;
   $_DBG_FH->open(">>$_DBG_OUTPUT");
   $_DBG_INDENT = 0;
   $_DBG_POINT  = 0;

   _DBG_line("#"x70);
   _DBG_line("# $function");
   _DBG_line("#"x70);
}

# End a debugging session.
sub _DBG_end {
   my($value) = @_;
   return  unless ($_DBG);

   _DBG_line("# Ending: $value");
   $_DBG_FH->close();
}

# Enter a routine.
sub _DBG_enter {
   my($routine) = @_;
   return  unless ($_DBG);
   $_DBG_POINT++;
   $_DBG_INDENT += 3;

   _DBG_line("### Entering[$_DBG_POINT]: $routine");
}

# Leave a routine.
sub _DBG_leave {
   my($value) = @_;
   return  unless ($_DBG);
   $_DBG_POINT++;

   _DBG_line("### Leaving[$_DBG_POINT]: $value");
   $_DBG_INDENT -= 3;
}

# Print a debugging line.
sub _DBG_line {
   my($line) = @_;
   print $_DBG_FH " "x$_DBG_INDENT,$line,"\n";
}

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
