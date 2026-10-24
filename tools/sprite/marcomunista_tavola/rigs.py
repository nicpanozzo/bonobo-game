# Gli scheletri dei disegni originali di Marco (pose del foglio #352). Coordinate a 1x nel fotogramma 304x196.
# Strati dal basso; 'claim' dice chi prende i pixel per primo; il resto va allo strato con rest=True.
import numpy as np

def pink(img):
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    return (((r > 150) & (g < 175) & (b > 80) & (r - g > 45)) | ((r > 225) & (g > 200) & (b > 200) & (img[..., 3] > 100))).astype(np.float32)

def notpink(img):
    return 1 - pink(img)

HEADLESS = None

IDLE = dict(src=('idle', 0),
    joints={'pelvis': (150, 138, None), 'chest': (150, 110, 'pelvis'), 'neck': (150, 82, 'chest'), 'headTop': (150, 20, 'neck'),
            'hipB': (134, 139, 'pelvis'), 'kneeB': (134, 152, 'hipB'), 'ankB': (136, 165, 'kneeB'), 'toeB': (152, 176, 'ankB'),
            'hipF': (164, 139, 'pelvis'), 'kneeF': (164, 152, 'hipF'), 'ankF': (167, 165, 'kneeF'), 'toeF': (186, 176, 'ankF')},
    layers=[
        dict(id='pelvis', fill=[[(118, 134), (180, 134), (180, 150), (118, 150)]], ink=False, handles=['pelvis', 'chest']),
        dict(id='legB', poly=[[(110, 137), (149, 137), (149, 159), (161, 159), (161, 185), (110, 185)]], handles=['hipB', 'kneeB', 'ankB', 'toeB']),
        dict(id='legF', poly=[[(149, 137), (182, 137), (182, 157), (201, 157), (201, 185), (146, 185), (146, 162), (149, 160)]], handles=['hipF', 'kneeF', 'ankF', 'toeF']),
        dict(id='torso', rest=True, handles=['pelvis', 'chest', 'neck']),
        dict(id='head', poly=[[(98, 2), (206, 2), (206, 74), (176, 80), (166, 87), (140, 87), (128, 79), (98, 79)]], handles=['neck', 'headTop'], rigid=True, ink=False),
    ], claim=['head', 'legF', 'legB'])

RUN = dict(src=('walk', 1),
    joints={'pelvis': (145, 138, None), 'chest': (155, 112, 'pelvis'), 'neck': (176, 98, 'chest'), 'headTop': (172, 30, 'neck'),
            'shoB': (148, 90, 'chest'), 'elbB': (122, 96, 'shoB'), 'wriB': (104, 104, 'elbB'), 'tipB': (88, 112, 'wriB'),
            'shoF': (164, 100, 'chest'), 'elbF': (185, 108, 'shoF'), 'wriF': (202, 120, 'elbF'), 'tipF': (212, 132, 'wriF'),
            'hipB': (128, 136, 'pelvis'), 'kneeB': (112, 142, 'hipB'), 'ankB': (98, 152, 'kneeB'), 'toeB': (90, 168, 'ankB'),
            'hipF': (145, 138, 'pelvis'), 'kneeF': (150, 152, 'hipF'), 'ankF': (165, 162, 'kneeF'), 'toeF': (190, 172, 'ankF')},
    layers=[
        dict(id='pelvis', fill=[[(110, 126), (165, 126), (165, 150), (110, 150)]], ink=False, handles=['pelvis', 'chest']),
        dict(id='legB', poly=[[(76, 134), (115, 128), (140, 134), (142, 140), (130, 148), (116, 152), (104, 164), (102, 182), (76, 182)]],
             handles=['hipB', 'kneeB', 'ankB', 'toeB'], noink=[[(108, 122), (146, 122), (146, 138), (108, 138)]]),
        dict(id='legF', poly=[[(118, 130), (160, 128), (162, 145), (168, 152), (200, 150), (206, 165), (198, 186), (150, 186), (148, 166), (140, 152), (130, 148), (142, 140), (140, 134)]],
             handles=['hipF', 'kneeF', 'ankF', 'toeF'], noink=[[(112, 122), (166, 122), (166, 137), (112, 137)]]),
        dict(id='armB', poly=[[(76, 88), (98, 84), (150, 80), (158, 90), (150, 96), (138, 100), (118, 104), (113, 110), (112, 120), (98, 124), (80, 122)]],
             handles=['shoB', 'elbB', 'wriB', 'tipB'], noink=[[(132, 76), (162, 76), (162, 102), (132, 102)]]),
        dict(id='torso', rest=True, handles=['pelvis', 'chest', 'neck'],
             inpaint=[[(160, 100), (178, 108), (185, 125), (165, 130), (158, 112)], [(110, 96), (150, 92), (150, 104), (115, 106)]]),
        dict(id='armF', poly=[[(160, 92), (186, 96), (205, 106), (214, 116), (220, 128), (214, 138), (200, 136), (190, 128), (176, 122), (168, 112), (160, 104)]],
             handles=['shoF', 'elbF', 'wriF', 'tipF'], noink=[[(152, 86), (170, 86), (170, 114), (152, 114)]]),
        dict(id='head', poly=[[(134, 0), (236, 0), (236, 82), (216, 90), (207, 101), (176, 103), (160, 97), (150, 86), (134, 82)]], handles=['neck', 'headTop'], rigid=True, ink=False),
    ], claim=['head', 'armF', 'armB', 'legF', 'legB'])

JUMP = dict(src=('jump', 0),
    joints={'pelvis': (150, 130, None), 'chest': (155, 108, 'pelvis'), 'neck': (168, 92, 'chest'), 'headTop': (170, 30, 'neck'),
            'shoB': (140, 104, 'chest'), 'elbB': (122, 82, 'shoB'), 'wriB': (108, 58, 'elbB'), 'tipB': (100, 38, 'wriB'),
            'shoF': (186, 102, 'chest'), 'elbF': (198, 86, 'shoF'), 'wriF': (205, 66, 'elbF'), 'tipF': (208, 48, 'wriF')},
    layers=[
        dict(id='armB', poly=[[(90, 24), (124, 24), (130, 58), (150, 92), (146, 114), (120, 104), (94, 72)]], handles=['shoB', 'elbB', 'wriB', 'tipB'],
             noink=[[(132, 88), (156, 88), (156, 118), (132, 118)]]),
        dict(id='torso', rest=True, handles=['pelvis', 'chest', 'neck']),
        dict(id='armF', poly=[[(197, 30), (224, 30), (224, 82), (206, 104), (190, 112), (180, 98), (190, 74), (197, 46)]], handles=['shoF', 'elbF', 'wriF', 'tipF'],
             noink=[[(176, 94), (196, 94), (196, 116), (176, 116)]]),
        dict(id='head', poly=[[(132, 24), (186, 24), (197, 30), (199, 45), (196, 60), (196, 92), (180, 100), (160, 98), (145, 90), (132, 70)]], handles=['neck', 'headTop'], rigid=True, ink=False),
    ], claim=['head', 'armF', 'armB'])

LIGHTAIR = dict(src=('lightAir', 0),
    joints={'pelvis': (150, 145, None), 'chest': (150, 122, 'pelvis'), 'neck': (162, 106, 'chest'), 'headTop': (160, 50, 'neck'),
            'shoB': (138, 112, 'chest'), 'elbB': (116, 112, 'shoB'), 'wriB': (100, 112, 'elbB'), 'tipB': (88, 112, 'wriB'),
            'shoF': (178, 112, 'chest'), 'elbF': (196, 111, 'shoF'), 'wriF': (214, 110, 'elbF'), 'tipF': (228, 112, 'wriF')},
    layers=[
        dict(id='armB', poly=[[(84, 96), (142, 98), (142, 130), (84, 130)]], handles=['shoB', 'elbB', 'wriB', 'tipB'], noink=[[(130, 92), (150, 92), (150, 134), (130, 134)]]),
        dict(id='torso', rest=True, handles=['pelvis', 'chest', 'neck']),
        dict(id='armF', poly=[[(172, 99), (232, 99), (232, 126), (172, 128)]], handles=['shoF', 'elbF', 'wriF', 'tipF'], noink=[[(165, 94), (182, 94), (182, 132), (165, 132)]]),
        dict(id='head', poly=[[(122, 40), (210, 40), (210, 100), (196, 104), (186, 112), (160, 114), (146, 108), (122, 98)]], handles=['neck', 'headTop'], rigid=True, ink=False),
    ], claim=['head', 'armF', 'armB'])

GRAB = dict(src=('grab', 0),
    joints={'feet': (120, 172, None), 'pelvis': (135, 148, 'feet'), 'chest': (140, 125, 'pelvis'), 'neck': (160, 110, 'chest'), 'headTop': (160, 50, 'neck'),
            'shoF': (160, 122, 'chest'), 'elbF': (185, 115, 'shoF'), 'wriF': (210, 108, 'elbF'), 'tipF': (228, 110, 'wriF')},
    layers=[
        dict(id='torso', rest=True, handles=['feet', 'pelvis', 'chest', 'neck'], inpaint=[[(158, 104), (178, 104), (178, 136), (158, 136)]]),
        dict(id='armF', poly=[[(158, 98), (234, 96), (234, 126), (200, 128), (176, 136), (158, 132)]], handles=['shoF', 'elbF', 'wriF', 'tipF'],
             noink=[[(150, 96), (166, 96), (166, 140), (150, 140)]]),
        dict(id='head', poly=[[(110, 36), (210, 36), (210, 100), (192, 104), (180, 112), (150, 114), (130, 104), (110, 96)]], handles=['neck', 'headTop'], rigid=True, ink=False),
    ], claim=['head', 'armF'])

LIGHT = dict(src=('light', 0),
    joints={'feet': (130, 178, None), 'pelvis': (135, 148, 'feet'), 'chest': (135, 122, 'pelvis'), 'neck': (150, 104, 'chest'), 'headTop': (140, 40, 'neck'),
            'shoF': (150, 117, 'chest'), 'elbF': (190, 113, 'shoF'), 'wriF': (222, 109, 'elbF'), 'tipF': (240, 112, 'wriF')},
    layers=[
        dict(id='torso', rest=True, handles=['feet', 'pelvis', 'chest', 'neck'], inpaint=[[(134, 104), (168, 103), (168, 136), (150, 138), (134, 128)]]),
        dict(id='armF', poly=[[(133, 104), (226, 97), (244, 103), (244, 123), (222, 123), (200, 124), (172, 131), (160, 135), (148, 137), (133, 127)]],
             handles=['shoF', 'elbF', 'wriF', 'tipF'], noink=[[(120, 98), (146, 98), (146, 140), (120, 140)]]),
        dict(id='head', poly=[[(88, 28), (212, 28), (212, 100), (200, 104), (188, 111), (160, 113), (140, 108), (126, 100), (88, 100)]],
             handles=['neck', 'headTop'], rigid=True, ink=False),
    ], claim=['head', 'armF'])

def fx_only(src, polys, also=(), extra_layers=(), claim_extra=(), head=None):
    """Un disegno intero più uno strato d'effetto (archi, scintille...) che si sfuma o si ingrandisce a parte.
    Con head: la testa è uno strato a sé, così gli schiacciamenti non deformano la faccia."""
    hl = [dict(id='head', poly=[head], ink=False)] if head else []
    return dict(src=src, joints={'root': (150, 182, None), 'top': (150, 20, 'root')},
        layers=[dict(id='body', rest=True, ink=False, under_px=14), *extra_layers, *hl, dict(id='fx', poly=polys, also=list(also), ink=False)],
        claim=['fx', *claim_extra, *(['head'] if head else [])])

HEAVY = fx_only(('heavy', 0), [[(240, 82), (292, 82), (292, 186), (240, 186)], [(212, 82), (240, 82), (240, 106), (212, 100)], [(205, 140), (240, 140), (240, 186), (205, 186)]],
                also=[([[(212, 100), (241, 100), (241, 141), (212, 141)]], pink)], head=[(100, 45), (210, 45), (210, 104), (200, 110), (190, 118), (160, 118), (145, 110), (115, 112), (100, 108)])
HEAVYUP = fx_only(('heavyUp', 0), [[(186, 12), (246, 12), (246, 156), (178, 156), (186, 128), (198, 100), (203, 76), (201, 50), (196, 30)]])
HEAVYAIR = fx_only(('heavyAir', 0), [[(219, 80), (268, 80), (268, 152), (205, 152), (205, 130), (219, 128)]], also=[([[(208, 86), (220, 86), (220, 130), (208, 130)]], pink)], head=[(100, 45), (212, 45), (212, 104), (200, 112), (190, 120), (160, 120), (140, 110), (110, 110), (100, 106)])
RECOVERY = fx_only(('recovery', 0), [[(188, 22), (242, 22), (242, 152), (184, 152), (196, 120), (204, 90), (200, 55)]])
LIGHTUP = fx_only(('lightUp', 0), [[(201, 84), (214, 84), (214, 134), (188, 134), (197, 117), (200, 100)]])
LIGHTDOWN = fx_only(('lightDown', 0), [[(207, 112), (250, 112), (250, 158), (213, 158)]], head=[(126, 50), (220, 50), (220, 112), (206, 120), (196, 132), (160, 132), (140, 122), (126, 118)])
HEAVYDOWN = fx_only(('heavyDown', 0), [[(196, 118), (248, 118), (248, 184), (196, 184), (190, 152)]], head=[(105, 50), (212, 50), (212, 118), (200, 126), (190, 138), (150, 138), (130, 125), (105, 122)])
SHIELD = fx_only(('shield', 0), [[(168, 12), (244, 12), (244, 194), (140, 194), (140, 178), (204, 176), (214, 150), (216, 112), (217, 92), (206, 68), (190, 44), (168, 34)]])
THROW = fx_only(('throw', 0), [[(221, 52), (292, 52), (292, 152), (214, 152), (214, 112)]],
                extra_layers=[dict(id='lines', poly=[[(213, 90), (222, 90), (222, 118), (213, 118)]], ink=False)], claim_extra=['lines'], head=[(115, 40), (212, 40), (212, 98), (204, 108), (196, 120), (165, 122), (140, 112), (115, 108)])
DASH = fx_only(('dash', 0), [[(52, 50), (120, 50), (120, 88), (100, 104), (52, 110)]], head=[(148, 38), (244, 38), (244, 113), (228, 114), (220, 120), (190, 121), (178, 108), (160, 100), (148, 100)])

def _omino(im):
    """Gli omini sono bianchi col tratto nero: niente oro attorno."""
    from scipy import ndimage as ndi
    c = im[..., :3]; mx, mn = c.max(-1), c.min(-1)
    m = ((mx - mn) < 60) | (mx < 90)
    m = ndi.binary_opening(m, iterations=1)
    return ndi.binary_dilation(m, iterations=1).astype(np.float32)

SUPREME = dict(src=('supreme', 0), joints={'root': (150, 182, None), 'top': (150, 20, 'root')},
    layers=[dict(id='aura', rest=True, ink=False, vignette=40, under_px=0),
            *[dict(id=f'om{i}', poly=[p], color=_omino, ink=False) for i, p in enumerate([
                [(34, 24), (76, 24), (76, 68), (34, 68)], [(26, 116), (76, 116), (76, 158), (26, 158)],
                [(240, 66), (276, 66), (276, 106), (240, 106)], [(218, 112), (272, 112), (272, 170), (218, 170)],
                [(230, 20), (264, 20), (264, 60), (230, 60)]])]],
    claim=['om0', 'om1', 'om2', 'om3', 'om4'])



LAND = dict(src=('land', 0), joints={'root': (150, 182, None), 'top': (150, 20, 'root')},
    layers=[dict(id='body', rest=True, ink=False, under_px=14), dict(id='head', poly=[[(116, 40), (224, 40), (224, 116), (212, 128), (200, 140), (172, 141), (160, 131), (144, 120), (122, 114), (116, 112)]], ink=False)],
    claim=['head'])

WHOLE = lambda name, k=0: dict(src=(name, k), joints={'root': (150, 182, None), 'top': (150, 20, 'root')}, layers=[dict(id='body', rest=True, ink=False)], claim=[])

ALL = dict(IDLE=IDLE, RUN=RUN, JUMP=JUMP, LIGHTAIR=LIGHTAIR, GRAB=GRAB, LIGHT=LIGHT, HEAVY=HEAVY, HEAVYUP=HEAVYUP, HEAVYAIR=HEAVYAIR,
           RECOVERY=RECOVERY, LIGHTUP=LIGHTUP, LIGHTDOWN=LIGHTDOWN, HEAVYDOWN=HEAVYDOWN, SHIELD=SHIELD, THROW=THROW, DASH=DASH, SUPREME=SUPREME,
           WALK0=WHOLE('walk', 0), FALL=WHOLE('fall'), LAND=LAND, HIT=WHOLE('hit'), SPN=WHOLE('specialNeutral'))
