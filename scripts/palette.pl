#!/usr/bin/env perl
# Derive ACCENT_DARK / ACCENT_SOFT / ACCENT_BG / DONE_DOT from an ACCENT hex.
# Real arithmetic (RGB mixing, HSL, WCAG contrast) implementing the rules in
# CLAUDE-CODE-RECOLOR.md step 2, instead of an LLM estimating the colour math
# by eye on every run.
#
# Usage: perl palette.pl '#RRGGBB'
# Prints: ACCENT_DARK=#.. ACCENT_SOFT=#.. ACCENT_BG=#.. DONE_DOT=#.. (one per line)
use strict;
use warnings;

my $accent = shift @ARGV or die "usage: palette.pl '#RRGGBB'\n";
die "not a hex colour: $accent\n" unless $accent =~ /^#?[0-9A-Fa-f]{6}$/;

sub hex2rgb {
  my ($h) = @_;
  $h =~ s/^#//;
  return (hex(substr($h, 0, 2)), hex(substr($h, 2, 2)), hex(substr($h, 4, 2)));
}

sub clamp { my ($v, $lo, $hi) = @_; return $v < $lo ? $lo : $v > $hi ? $hi : $v; }

sub rgb2hex {
  my ($r, $g, $b) = @_;
  return sprintf("#%02X%02X%02X", clamp(int($r + 0.5), 0, 255), clamp(int($g + 0.5), 0, 255), clamp(int($b + 0.5), 0, 255));
}

sub mix_rgb {
  # t=0 -> all of (r1,g1,b1); t=1 -> all of (r2,g2,b2)
  my ($r1, $g1, $b1, $r2, $g2, $b2, $t) = @_;
  return ($r1 * (1 - $t) + $r2 * $t, $g1 * (1 - $t) + $g2 * $t, $b1 * (1 - $t) + $b2 * $t);
}

sub rgb2hsl {
  my ($r, $g, $b) = @_;
  $r /= 255; $g /= 255; $b /= 255;
  my $max = $r > $g ? ($r > $b ? $r : $b) : ($g > $b ? $g : $b);
  my $min = $r < $g ? ($r < $b ? $r : $b) : ($g < $b ? $g : $b);
  my $l = ($max + $min) / 2;
  my ($h, $s) = (0, 0);
  if ($max != $min) {
    my $d = $max - $min;
    $s = $l > 0.5 ? $d / (2 - $max - $min) : $d / ($max + $min);
    if ($max == $r) { $h = ($g - $b) / $d + ($g < $b ? 6 : 0); }
    elsif ($max == $g) { $h = ($b - $r) / $d + 2; }
    else { $h = ($r - $g) / $d + 4; }
    $h /= 6;
  }
  return ($h * 360, $s * 100, $l * 100);
}

sub hue2rgb {
  my ($p, $q, $t) = @_;
  $t += 1 if $t < 0;
  $t -= 1 if $t > 1;
  return $p + ($q - $p) * 6 * $t if $t < 1 / 6;
  return $q if $t < 1 / 2;
  return $p + ($q - $p) * (2 / 3 - $t) * 6 if $t < 2 / 3;
  return $p;
}

sub hsl2rgb {
  my ($h, $s, $l) = @_;
  $h /= 360; $s /= 100; $l /= 100;
  my ($r, $g, $b);
  if ($s == 0) { $r = $g = $b = $l; }
  else {
    my $q = $l < 0.5 ? $l * (1 + $s) : $l + $s - $l * $s;
    my $p = 2 * $l - $q;
    $r = hue2rgb($p, $q, $h + 1 / 3);
    $g = hue2rgb($p, $q, $h);
    $b = hue2rgb($p, $q, $h - 1 / 3);
  }
  return ($r * 255, $g * 255, $b * 255);
}

sub srgb_to_linear {
  my $c = shift() / 255;
  return $c <= 0.03928 ? $c / 12.92 : (($c + 0.055) / 1.055)**2.4;
}

sub relative_luminance {
  my ($r, $g, $b) = @_;
  return 0.2126 * srgb_to_linear($r) + 0.7152 * srgb_to_linear($g) + 0.0722 * srgb_to_linear($b);
}

sub contrast_with_white {
  my $l = relative_luminance(@_);
  return 1.05 / ($l + 0.05);
}

my ($ar, $ag, $ab) = hex2rgb($accent);
my ($h, $s, $l) = rgb2hsl($ar, $ag, $ab);

my ($dr, $dg, $db);
if ($h >= 45 && $h <= 65) {
  # Yellow family: chasing 4.5:1 contrast darkens straight through "gold" into
  # muddy olive/brown. Keep it close to ACCENT and vivid instead.
  ($dr, $dg, $db) = mix_rgb($ar, $ag, $ab, 0, 0, 0, 0.12);
} else {
  my $t = 0.20;
  ($dr, $dg, $db) = mix_rgb($ar, $ag, $ab, 0, 0, 0, $t);
  while (contrast_with_white($dr, $dg, $db) < 4.5 && $t < 0.85) {
    $t += 0.08;
    ($dr, $dg, $db) = mix_rgb($ar, $ag, $ab, 0, 0, 0, $t);
  }
  my ($dh, $ds, $dl) = rgb2hsl($dr, $dg, $db);
  $ds = clamp($ds * 1.12, 0, 100);
  ($dr, $dg, $db) = hsl2rgb($dh, $ds, $dl);
}

my ($sr, $sg, $sb) = mix_rgb($ar, $ag, $ab, 255, 255, 255, 0.35);
my ($br, $bgc, $bb) = mix_rgb($ar, $ag, $ab, 0x1E, 0x1E, 0x1E, 0.80);

# Clearly different from ACCENT and from the blue "working" dot (#3B82F6).
# Green/teal accents (~80-200 deg) get amber instead; everything else gets green.
my $done_dot = ($h >= 80 && $h <= 200) ? "#F59E0B" : "#22C55E";

print "ACCENT_DARK=" . rgb2hex($dr, $dg, $db) . "\n";
print "ACCENT_SOFT=" . rgb2hex($sr, $sg, $sb) . "\n";
print "ACCENT_BG=" . rgb2hex($br, $bgc, $bb) . "\n";
print "DONE_DOT=$done_dot\n";
