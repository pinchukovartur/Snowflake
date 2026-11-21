import 'package:flutter/material.dart';

import '../app_state.dart';
import 'advent.dart';
import 'shop_dialog.dart';

/// Where a locked paper or stencil ([item]) is to be had, opened over the
/// screen: the shop, on its demo flake there, if a set holds it (its papers
/// in [colour], see [showShop]); else the advent calendar, whose door it is
/// behind.
Future<void> showWhereToGet(BuildContext context, GameState game, ({bool paper, String id}) item, {Color? colour}) =>
    offers.any((o) => o.items.any((r) => r.id == item.id)) ? showShop(context, game, trying: item, colour: colour) : showAdvent(context, game);
