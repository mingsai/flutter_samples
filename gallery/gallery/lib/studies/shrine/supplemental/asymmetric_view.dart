// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:gallery/data/gallery_options.dart';
import 'package:gallery/layout/text_scale.dart';
import 'package:gallery/studies/shrine/category_menu_page.dart';
import 'package:gallery/studies/shrine/model/product.dart';
import 'package:gallery/studies/shrine/page_status.dart';
import 'package:gallery/studies/shrine/supplemental/desktop_product_columns.dart';
import 'package:gallery/studies/shrine/supplemental/product_columns.dart';
import 'package:gallery/studies/shrine/supplemental/product_card.dart';

const _topPadding = 34.0;
const _bottomPadding = 44.0;

const _cardToScreenWidthRatio = 0.59;

class MobileAsymmetricView extends StatelessWidget {
  const MobileAsymmetricView({Key key, this.products}) : super(key: key);

  final List<Product> products;

  List<Container> _buildColumns(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    if (products == null || products.isEmpty) {
      return const [];
    }

    // Decide whether the page size and text size allow 2-column products.

    final double cardHeight = (constraints.biggest.height -
            _topPadding -
            _bottomPadding -
            TwoProductCardColumn.spacerHeight) /
        2;

    final double imageWidth =
        _cardToScreenWidthRatio * constraints.biggest.width -
            TwoProductCardColumn.horizontalPadding;

    final double imageHeight = cardHeight -
        MobileProductCard.defaultTextBoxHeight *
            GalleryOptions.of(context).textScaleFactor(context);

    final bool shouldUseAlternatingLayout =
        imageHeight > 0 && imageWidth / imageHeight < 49 / 33;

    if (shouldUseAlternatingLayout) {
      // Alternating layout: a layout of alternating 2-product
      // and 1-product columns.
      //
      // This will return a list of columns. It will oscillate between the two
      // kinds of columns. Even cases of the index (0, 2, 4, etc) will be
      // TwoProductCardColumn and the odd cases will be OneProductCardColumn.
      //
      // Each pair of columns will advance us 3 products forward (2 + 1). That's
      // some kinda awkward math so we use _evenCasesIndex and _oddCasesIndex as
      // helpers for creating the index of the product list that will correspond
      // to the index of the list of columns.

      return List<Container>.generate(_listItemCount(products.length), (index) {
        double width =
            _cardToScreenWidthRatio * MediaQuery.of(context).size.width;
        Widget column;
        if (index % 2 == 0) {
          /// Even cases
          final int bottom = _evenCasesIndex(index);
          column = TwoProductCardColumn(
            bottom: products[bottom],
            top:
                products.length - 1 >= bottom + 1 ? products[bottom + 1] : null,
            imageAspectRatio: imageWidth / imageHeight,
          );
          width += 32;
        } else {
          /// Odd cases
          column = OneProductCardColumn(
            product: products[_oddCasesIndex(index)],
            reverse: true,
          );
        }
        return Container(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: column,
          ),
        );
      }).toList();
    } else {
      // Alternating layout: a layout of 1-product columns.

      return [
        for (final product in products)
          Container(
            width: _cardToScreenWidthRatio * MediaQuery.of(context).size.width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OneProductCardColumn(
                product: product,
                reverse: false,
              ),
            ),
          )
      ];
    }
  }

  int _evenCasesIndex(int input) {
    // The operator ~/ is a cool one. It's the truncating division operator. It
    // divides the number and if there's a remainder / decimal, it cuts it off.
    // This is like dividing and then casting the result to int. Also, it's
    // functionally equivalent to floor() in this case.
    return input ~/ 2 * 3;
  }

  int _oddCasesIndex(int input) {
    assert(input > 0);
    return (input / 2).ceil() * 3 - 1;
  }

  int _listItemCount(int totalItems) {
    return (totalItems % 3 == 0)
        ? totalItems ~/ 3 * 2
        : (totalItems / 3).ceil() * 2 - 1;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PageStatus.of(context).cartController,
      builder: (context, child) => AnimatedBuilder(
        animation: PageStatus.of(context).menuController,
        builder: (context, child) => ExcludeSemantics(
          excluding: !productPageIsVisible(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  0,
                  _topPadding,
                  16,
                  _bottomPadding,
                ),
                children: _buildColumns(context, constraints),
                physics: const AlwaysScrollableScrollPhysics(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class DesktopAsymmetricView extends StatelessWidget {
  const DesktopAsymmetricView({Key key, this.products}) : super(key: key);

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final Widget _gap = Container(width: 24);
    final Widget _flex = Expanded(flex: 1, child: Container());

    // Determine the scale factor for the desktop asymmetric view.

    final double textScaleFactor =
        GalleryOptions.of(context).textScaleFactor(context);

    // When text is larger, the images becomes wider, but at half the rate.
    final double imageScaleFactor = reducedTextScale(context);

    // When text is larger, horizontal padding becomes smaller.
    final double paddingScaleFactor = textScaleFactor >= 1.5 ? 0.25 : 1;

    // Calculate number of columns

    final double sidebar = desktopCategoryMenuPageWidth(context: context);
    final double minimumBoundaryWidth = 84 * paddingScaleFactor;
    final double columnWidth = 186 * imageScaleFactor;
    final double columnGapWidth = 24 * imageScaleFactor;
    final double windowWidth = MediaQuery.of(context).size.width;

    final int columnCount = max(
      1,
      ((windowWidth + columnGapWidth - 2 * minimumBoundaryWidth - sidebar) /
              (columnWidth + columnGapWidth))
          .floor(),
    );

    // Limit column width to fit within window when there is only one column.
    final double actualColumnWidth = columnCount == 1
        ? min(
            columnWidth,
            windowWidth - sidebar - 2 * minimumBoundaryWidth,
          )
        : columnWidth;

    final List<DesktopProductCardColumn> productCardColumns =
        List<DesktopProductCardColumn>.generate(columnCount, (currentColumn) {
      final bool alignToEnd =
          (currentColumn % 2 == 1) || (currentColumn == columnCount - 1);
      final bool startLarge = (currentColumn % 2 == 1);
      return DesktopProductCardColumn(
        columnCount: columnCount,
        currentColumn: currentColumn,
        alignToEnd: alignToEnd,
        startLarge: startLarge,
        products: products,
        largeImageWidth: actualColumnWidth,
        smallImageWidth:
            columnCount > 1 ? columnWidth - columnGapWidth : actualColumnWidth,
      );
    });

    return AnimatedBuilder(
      animation: PageStatus.of(context).cartController,
      builder: (context, child) => ExcludeSemantics(
        excluding: !productPageIsVisible(context),
        child: ListView(
          scrollDirection: Axis.vertical,
          children: [
            Container(height: 60),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _flex,
                ...List<Widget>.generate(
                  2 * columnCount - 1,
                  (generalizedColumnIndex) {
                    if (generalizedColumnIndex % 2 == 0) {
                      return productCardColumns[generalizedColumnIndex ~/ 2];
                    } else {
                      return _gap;
                    }
                  },
                ),
                _flex,
              ],
            ),
            Container(height: 60),
          ],
          physics: const AlwaysScrollableScrollPhysics(),
        ),
      ),
    );
  }
}
