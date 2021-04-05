// SPDX-License-Identifier: GPL-2.0-only

#include <linux/init.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>

#include <sound/soc.h>

static int aon1100e3_component_probe(struct snd_soc_component *component)
{
	printk(KERN_INFO "AON1100 E3 Component Probe\n");
	return 0;
}

static const struct snd_soc_dapm_widget aon1100e3_dapm_widgets[] = {
	SND_SOC_DAPM_INPUT("RX_I2S_SDIN"),
	SND_SOC_DAPM_OUTPUT("TX_I2S_SDO"),
};

static const struct snd_soc_dapm_route aon1100e3_audio_routes[] = {
	{ "RX_I2S_SDIN", NULL , "Playback"}, // OUT from Pi
	{ "Capture", NULL , "TX_I2S_SDO"},
};

	
static struct snd_soc_dai_driver aon1100e3_dai = {
	.name = "aon1100e3-avs",
	.playback = {
		.stream_name = "Playback",
		.channels_min = 1,
		.channels_max = 2,
		.rates = SNDRV_PCM_RATE_16000,
		.formats = SNDRV_PCM_FMTBIT_S16_LE,},
	.capture = {
		.stream_name = "Capture",
		.channels_min = 1,
		.channels_max = 2,
		.rates = SNDRV_PCM_RATE_16000,
		.formats = SNDRV_PCM_FMTBIT_S16_LE,},
	.symmetric_rates = 1,
};


static const struct snd_soc_component_driver aon1100e3_component_driver = {
	.probe			    = aon1100e3_component_probe,
	.dapm_widgets		= aon1100e3_dapm_widgets,
	.num_dapm_widgets	= ARRAY_SIZE(aon1100e3_dapm_widgets),
	.dapm_routes		= aon1100e3_audio_routes,
	.num_dapm_routes	= ARRAY_SIZE(aon1100e3_audio_routes),
	.endianness		= 1,
	.non_legacy_dai_naming	= 1,
};

static int aon1100e3_probe(struct platform_device *pdev)
{
	printk(KERN_INFO "AON1100 E3 Probe\n");
	return devm_snd_soc_register_component(&pdev->dev,
			&aon1100e3_component_driver, &aon1100e3_dai, 1);
}

static int aon1100e3_remove(struct platform_device *pdev)
{
	return 0;
}

static const struct of_device_id aon1100e3_of_match[] = {
	{ .compatible = "aon,aon1100e3", },
	{ }
};
MODULE_DEVICE_TABLE(of, aon1100e3_of_match);

static struct platform_driver aon1100e3_driver = {
	.driver = {
		.name = "aon1100e3",
		.of_match_table	= of_match_ptr(aon1100e3_of_match),
	},
	.probe = aon1100e3_probe,
	.remove = aon1100e3_remove,
};

module_platform_driver(aon1100e3_driver);

MODULE_DESCRIPTION("AON1100 E3 driver");
MODULE_AUTHOR("AON");
MODULE_LICENSE("GPL");
