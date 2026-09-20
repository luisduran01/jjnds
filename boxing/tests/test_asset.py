import json, struct, pathlib, unittest

class AssetTests(unittest.TestCase):
    def test_generated_character_has_weighted_original_geometry(self):
        p = pathlib.Path('boxing/characters/boxer_rigged.glb')
        self.assertTrue(p.exists(), 'Generated rig is missing')
        b=p.read_bytes(); g=json.loads(b[20:20+struct.unpack_from('<I',b,12)[0]])
        self.assertGreaterEqual(len(g['skins'][0]['joints']), 17)
        attrs=g['meshes'][0]['primitives'][0]['attributes']
        self.assertEqual(g['accessors'][attrs['POSITION']]['count'],97923)
        self.assertIn('JOINTS_0',attrs)
        self.assertIn('WEIGHTS_0',attrs)

if __name__=='__main__': unittest.main()
