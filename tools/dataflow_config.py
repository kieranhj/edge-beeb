"""
dataflow_config.py - what beebgame's dataflow analyses need to know about
Edge Grinder (tools/beebasm_dataflow.py passes it as --config). Every field is
documented in beeb-port-kit's template/tools/dataflow/gamecfg.py.
"""

# beebasm_dataflow.py's own: the -v listing to read (the default build: VGI
# music, the C64's graphics), and the source folders its address-taken scan
# reads.
LISTING = 'build/EDGE.lst'
SOURCES = ('src', 'lib')

# The findings are reported against build/dataflow-in/src/listing.s.
GAME_DIR = 'src'

# The interrupt: install_irq (src/rupture.asm) puts irq_handler in IRQ1V, and
# nothing else is ever stored there; rupt_vsync, rupt_timer and the VGI player
# in HAZEL are reached from it. It can run between any two instructions:
# every byte it reads is live everywhere.
ISR_ROOTS = ('irq_handler',)

VAR_SEGMENTS = ()
