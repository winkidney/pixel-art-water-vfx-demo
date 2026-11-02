"""Default narration generator: the selected Higgs Q8 fixed-reference method."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).with_name("synthesize_higgs.py")), run_name="__main__")
