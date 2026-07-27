import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

/// Provides utility methods for managing contact-related UI data and
/// persisted contact metadata.
///
/// This class is stateless and can be instantiated as a `const` object.
class ContactService {
  const ContactService();

  /// Returns a collection of predefined gradient/text color combinations.
  ///
  /// The returned list is typically used to assign visually distinct accent
  /// colors to UI elements such as avatars, cards, or category chips.
  ///
  /// Includes:
  /// * Theme-derived primary, secondary, tertiary, and error gradients.
  /// * Random hue-rotated variants of each gradient to increase visual variety.
  ///
  /// The accompanying `text` color is chosen to provide appropriate contrast
  /// against each gradient.
  static List<({List<Color> gradient, Color text})> colorOptions(
    BuildContext context,
  ) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return [
      (
        gradient: [scheme.primary, scheme.primaryContainer],
        text: scheme.onPrimary,
      ),
      (
        gradient: [scheme.secondary, scheme.secondaryContainer],
        text: scheme.onSecondary,
      ),
      (
        gradient: [scheme.tertiary, scheme.tertiaryContainer],
        text: scheme.onTertiary,
      ),
      (gradient: [scheme.error, scheme.errorContainer], text: scheme.onError),
      (
        gradient: rotateHue([scheme.primary, scheme.primaryContainer]),
        text: scheme.onPrimary,
      ),
      (
        gradient: rotateHue([scheme.secondary, scheme.secondaryContainer]),
        text: scheme.onSecondary,
      ),
      (
        gradient: rotateHue([scheme.tertiary, scheme.tertiaryContainer]),
        text: scheme.onTertiary,
      ),
      (
        gradient: rotateHue([scheme.error, scheme.errorContainer]),
        text: scheme.onError,
      ),
    ];
  }

  /// Returns a new gradient with its hue randomly rotated.
  ///
  /// Both colors are shifted by the same random hue offset, preserving the
  /// original relationship between the gradient colors while producing a
  /// visually distinct variation.
  ///
  /// Useful for generating themed color variants without manually defining
  /// additional palettes.
  static List<Color> rotateHue(List<Color> gradient) {
    double rand = Random().nextDouble() * 360;
    HSVColor hsv0 = HSVColor.fromColor(gradient[0]);
    HSVColor hsv1 = HSVColor.fromColor(gradient[1]);
    return [
      hsv0.withHue((hsv0.hue + rand) % 360).toColor(),
      hsv1.withHue((hsv1.hue + rand) % 360).toColor(),
    ];
  }

  /// Adds [contactID] to the list of quick contacts.
  ///
  /// The contact ID is appended to the `ids` array stored in the `quick` row,
  /// then the `count` field is updated to reflect the current number of IDs.
  static void insertQuickContact(String contactID) async {
    await executeBatchSql(
      sql:
          """
        UPDATE contacts
        SET value = json_insert(value, '\$.ids[#]', '$contactID')
        WHERE key = 'quick';
        UPDATE contacts
        SET value = json_set(value, '\$.count', json_array_length(json_extract(value, '\$.ids')))
        WHERE key = 'quick';
        """,
    );
  }

  /// Removes [contactID] from the list of quick contacts.
  ///
  /// If the contact ID exists in the `ids` array of the `quick` row, it is
  /// removed and the `count` field is updated to match the remaining entries.
  static void deleteQuickContact(String contactID) async {
    await executeBatchSql(
      sql:
          """
        UPDATE contacts
        SET value = json_set(
            contacts.value,
            '\$.ids',
            COALESCE(
                (
                    SELECT json_group_array(json_each.value)
                    FROM json_each(contacts.value, '\$.ids')
                    WHERE json_each.value <> '$contactID'
                ),
                json('[]')
            )
        )
        WHERE key = 'quick';
        UPDATE contacts
        SET value = json_set(value, '\$.count', json_array_length(json_extract(value, '\$.ids')))
        WHERE key = 'quick';
        """,
    );
  }

  /// Inserts or replaces a contact's preference object.
  ///
  /// If a contact with the same `id` already exists in the `contacts` array of
  /// the `preferences` row, it is replaced with [contactPrefs]. Otherwise, the
  /// preference object is appended to the array. The `count` field is then
  /// updated to reflect the total number of stored preference objects.
  ///
  /// The [contactPrefs] map must contain an `id` key.
  static void insertContactPrefs(Map<String, dynamic> contactPrefs) async {
    final id = contactPrefs['id'];
    await executeBatchSql(
      sql:
          """
        UPDATE contacts
        SET value = json_set(
            contacts.value,
            '\$.contacts',
            (
                SELECT json_group_array(json(value))
                FROM (
                    -- Keep all other contacts
                    SELECT json_each.value AS value
                    FROM json_each(contacts.value, '\$.contacts')
                    WHERE json_extract(json_each.value, '\$.id') <> '$id'

                    UNION ALL

                    -- Append the new/updated contact
                    SELECT json('${jsonEncode(contactPrefs)}')
                )
            )
        )
        WHERE key = 'preferences';
        UPDATE contacts
        SET value = json_set(
            value,
            '\$.count',
            json_array_length(json_extract(value, '\$.contacts'))
        )
        WHERE key = 'preferences';
        """,
    );
  }

  /// Removes the preference object associated with [contactID].
  ///
  /// If a contact whose `id` matches [contactID] exists in the `contacts` array
  /// of the `preferences` row, it is removed and the `count` field is updated
  /// to reflect the remaining preference objects.
  static void deleteContactPrefs(String contactID) async {
    await executeBatchSql(
      sql:
          """
        UPDATE contacts
        SET value = json_set(
            contacts.value,
            '\$.contacts',
            COALESCE(
                (
                    SELECT json_group_array(json_each.value)
                    FROM json_each(contacts.value, '\$.contacts')
                    WHERE json_extract(json_each.value, '\$.id') <> '$contactID'
                ),
                json('[]')
            )
        )
        WHERE key = 'preferences';
        UPDATE contacts
        SET value = json_set(
            value,
            '\$.count',
            json_array_length(json_extract(value, '\$.contacts'))
        )
        WHERE key = 'preferences';
        """,
    );
  }
}
