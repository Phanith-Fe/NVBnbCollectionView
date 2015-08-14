//
//  NVBnbCollectionView.m
//  NVBnbCollectionView
//
//  Created by Nguyen Vinh on 8/8/15.
//
//

#import "NVBnbCollectionView.h"

#import "NVBnbCollectionViewParallaxCell.h"

static NSString *kMoreLoaderIdentifier = @"moreLoader";

@implementation NVBnbCollectionView {
    __weak id<NVBnbCollectionViewDataSource> _bnbDataSource;
    CADisplayLink *_displayLink;
    UIInterfaceOrientation _currentOrientation;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self setUp];
        [self setUpParallax];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setUp];
        [self setUpParallax];
    }
    
    return self;
}

- (void)setUp {
    self.enableLoadMore = true;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
    [self registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:NVBnbCollectionElementKindMoreLoader withReuseIdentifier:kMoreLoaderIdentifier];
    [self addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)didChangeValueForKey:(NSString *)key {
    if ([key isEqualToString:@"contentOffset"]) {
        if ((UIInterfaceOrientationIsPortrait(_currentOrientation) && self.contentOffset.y > (self.contentSize.height - self.frame.size.height))
            || (UIInterfaceOrientationIsLandscape(_currentOrientation) && self.contentOffset.y > (self.contentSize.width - self.frame.size.width))) {
            NSLog(@"contentOffset changed");
            // Load more
            if (self.enableLoadMore && !self.loadingMore) {
                [self loadMore];
            }
        }
    }
}

- (void)dealloc {
    [_displayLink invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeObserver:self forKeyPath:@"contentOffset"];
}

- (void)setDataSource:(id<UICollectionViewDataSource>)dataSource {
    [super setDataSource:self];
    
    _bnbDataSource = (id<NVBnbCollectionViewDataSource>) dataSource;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if ([_bnbDataSource respondsToSelector:@selector(numberOfItemsInBnbCollectionView:)]) {
        return [_bnbDataSource numberOfItemsInBnbCollectionView:self];
    }
    
    return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (![_bnbDataSource respondsToSelector:@selector(bnbCollectionView:cellForItemAtIndexPath:)]
        || ![_bnbDataSource respondsToSelector:@selector(bnbCollectionView:parallaxCellForItemAtIndexPath:)]) {
        return nil;
    }
    
    if ((indexPath.row % 10 % 3 == 0) && (indexPath.row % 10 / 3 % 2 == 1)) {
        NVBnbCollectionViewParallaxCell *cell = [_bnbDataSource bnbCollectionView:self parallaxCellForItemAtIndexPath:indexPath];
        NVBnbCollectionViewLayout *layout = (NVBnbCollectionViewLayout *) collectionView.collectionViewLayout;
        
        cell.maxParallaxOffset = layout.maxParallaxOffset;
        cell.currentOrienration = layout.currentOrientation;
        
        return cell;
    }
    
    return [_bnbDataSource bnbCollectionView:self cellForItemAtIndexPath:indexPath];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if ([kind isEqualToString:NVBnbCollectionElementKindHeader]) {
        UICollectionReusableView *header = [_bnbDataSource bnbCollectionView:self headerAtIndexPath:indexPath];
        
        return header;
    } else if ([kind isEqualToString:NVBnbCollectionElementKindMoreLoader]){
        UICollectionReusableView *moreLoader = [self dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kMoreLoaderIdentifier forIndexPath:indexPath];
        UIView *moreLoaderView = [moreLoader viewWithTag:1];;
        
        if (!moreLoaderView) {
            if ([_bnbDataSource respondsToSelector:@selector(bnbCollectionView:moreLoaderAtIndexPath:)]) {
                moreLoaderView = [_bnbDataSource bnbCollectionView:self moreLoaderAtIndexPath:indexPath];
            }
            if (!moreLoaderView) {
                moreLoaderView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
                [((UIActivityIndicatorView *) moreLoaderView) startAnimating];
            }
            moreLoaderView.center = CGPointMake(moreLoader.bounds.size.width / 2, moreLoader.bounds.size.height / 2);
            moreLoaderView.tag = 1;
            [moreLoader addSubview:moreLoaderView];
        }
        
        return moreLoader;
    }
    
    return nil;
}

#pragma mark - Parallax

- (void)setUpParallax {
    __weak id weakSelf = self;
    
    _displayLink = [CADisplayLink displayLinkWithTarget:weakSelf selector:@selector(doParallax:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)doParallax:(CADisplayLink *)displayLink {
//    NSLog(@"doParallax");
    
    NSArray *visibleCells = self.visibleCells;
    
    for (UICollectionViewCell *cell in visibleCells) {
        if ([cell isKindOfClass:[NVBnbCollectionViewParallaxCell class]]) {
            NVBnbCollectionViewParallaxCell *parallaxCell = (NVBnbCollectionViewParallaxCell *) cell;
            
            CGRect bounds = self.bounds;
            CGPoint boundsCenter = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
            CGPoint cellCenter = parallaxCell.center;
            CGPoint offsetFromCenter = CGPointMake(boundsCenter.x - cellCenter.x, boundsCenter.y - cellCenter.y);
            CGSize cellSize = parallaxCell.bounds.size;
            CGFloat maxVerticalOffset = (bounds.size.height / 2) + (cellSize.height / 2);
            CGFloat scaleFactor = parallaxCell.maxParallaxOffset / maxVerticalOffset;
            CGPoint parallaxOffset;
            
            if (parallaxCell.currentOrienration == UIInterfaceOrientationMaskPortrait) {
                parallaxOffset = CGPointMake(0, -offsetFromCenter.y * scaleFactor);
            } else {
                parallaxOffset = CGPointMake(-offsetFromCenter.x * scaleFactor, 0);
            }
            
            parallaxCell.parallaxImageOffset = parallaxOffset;
        }
    }
}

#pragma mark - Orientation

- (void)orientationChanged:(NSNotification *)notification {
    _currentOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    // Trick to cause layout update immediately
    self.contentOffset = CGPointMake(self.contentOffset.x + 1, self.contentOffset.y + 1);
    NSLog(@"orientationChanged");
}

#pragma mark - Load more

- (void)loadMore {
    if ([self.delegate conformsToProtocol:@protocol(NVBnbCollectionViewDelegate)]
        && [self.delegate respondsToSelector:@selector(loadMoreInBnbCollectionView:)]) {
        self.loadingMore = true;
        [(id<NVBnbCollectionViewDelegate>) self.delegate loadMoreInBnbCollectionView:self];
    }
}

@end
