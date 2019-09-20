#!/usr/bin/python
import png,argparse,sys,math,bbc

##########################################################################
##########################################################################

def main(options):
    image=bbc.load_png(options.input_path,
                    options.mode,
                    options._160,
                    options.transparent_output,
                    options.transparent_rgb,
                    not options.quiet)

    if len(image[0]) % options.sprite_width != 0:
        print>>sys.stderr,'WARNING: Sheet width %d is not a multiple of sprite width %d'%(len(image[0]),options.sprite_width)

    sprite_columns=len(image[0])/options.sprite_width

    if len(image) % options.sprite_height != 0:
        print>>sys.stderr,'WARNING: Sheet height %d is not a multiple of sprite height %d'%(len(image),options.sprite_height)

    sprite_rows=len(image)/options.sprite_height

    total_sprites = options.total_sprites if options.total_sprites else sprite_columns*sprite_rows

    for sp_y in range(1,len(image),options.sprite_height)
        for sp_x in range(1,len(image[0]),options.sprite_width)
            for y in range(options.sprite_height)
                print 



##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output BBC data to %(metavar)s')
    parser.add_argument('-m',dest='mask_output_path',metavar='FILE',help='output BBC destination mask data to %(metavar)s')
    parser.add_argument('--inf',action='store_true',help='if -o specified, also produce a 0-byte .inf file')
    parser.add_argument('--160',action='store_true',dest='_160',help='double width (Mode 5/2) aspect ratio')
    parser.add_argument('-p','--palette',help='specify BBC palette')
    parser.add_argument('--transparent-output',
                        default=None,
                        type=int,
                        help='specify output index to use for transparent PNG pixels')
    parser.add_argument('--transparent-rgb',
                        default=None,
                        type=int,
                        nargs=3,
                        help='specify opaque RGB to be interpreted as transparent')
    parser.add_argument('--total-sprites',
                        default=None,
                        type=int,
                        help='total number of sprites (if sheet isn\'t complete)')
    parser.add_argument('-q','--quiet',action='store_true',help='don\'t print warnings')
    parser.add_argument('input_path',metavar='FILE',help='load PNG data fro %(metavar)s')
    parser.add_argument('mode',type=int,help='screen mode')
    parser.add_argument('sprite_width',type=int,help='sprite width')
    parser.add_argument('sprite_height',type=int,help='sprite height')
    main(parser.parse_args())
