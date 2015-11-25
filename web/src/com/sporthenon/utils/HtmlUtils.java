package com.sporthenon.utils;

import java.sql.Timestamp;
import java.text.SimpleDateFormat;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpServletRequest;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.select.Elements;

import com.sporthenon.db.DatabaseHelper;
import com.sporthenon.db.entity.Athlete;
import com.sporthenon.db.entity.Result;
import com.sporthenon.db.entity.meta.Contributor;
import com.sporthenon.db.entity.meta.ExternalLink;
import com.sporthenon.db.entity.meta.RefItem;
import com.sporthenon.utils.res.ResourceUtils;

public class HtmlUtils {

	public final static String RARROW = "&nbsp;&#10137;&nbsp;";
	
	public static String writeNoResult(String lang) {
		return "<div class='noresult'>" + ResourceUtils.getText("no.result", lang) + "</div>";
	}
	
	public static String writeImage(short type, Object id, char size, String year, String title) {
		StringBuffer html = new StringBuffer();
		final String name = type + "-" + id + "-" + size;
		String name2 = "";
		if (type == ImageUtils.INDEX_SPORT_CHAMPIONSHIP || type == ImageUtils.INDEX_SPORT_EVENT)
			name2 = (type == ImageUtils.INDEX_SPORT_CHAMPIONSHIP ? ImageUtils.INDEX_CHAMPIONSHIP : ImageUtils.INDEX_EVENT) + "-" + String.valueOf(id).split("\\-")[1] + "-" + size;
		LinkedList<String> list = new LinkedList<String>();
		LinkedList<String> list2 = new LinkedList<String>();
		for (String s : ImageUtils.getImgFiles()) {
			if (s.startsWith(name)) {
				boolean isInclude = true;
				if (StringUtils.notEmpty(year)) {
					String[] t = s.replaceAll("^" + name + "(\\_|)|(gif|png)$|(\\_\\d+|)\\.", "").split("\\-");
					try {
						if (t.length > 1) {
							Integer y = Integer.parseInt(year.contains("-") || year.contains("/") ? year.substring(year.length() - 4) : year);
							Integer y1 = Integer.parseInt(t[0].equalsIgnoreCase("X") ? "0" : t[0]);
							Integer y2 = Integer.parseInt(t[1].equalsIgnoreCase("X") ? "5000" : t[1]);
							isInclude = (y >= y1 && y <= y2);
						}
					}
					catch (NumberFormatException e) {}
				}
				else
					isInclude = !s.matches(".*\\d{4}\\-\\d{4}\\.(gif|png)$");
				if (isInclude)
					list.add(s);
			}
			else if (StringUtils.notEmpty(name2) && s.startsWith(name2))
				list2.add(s);
		}
		if (list.isEmpty())
			list.addAll(list2);
		Collections.sort(list);
		if (!list.isEmpty())
			html.append("<img alt=''" + (StringUtils.notEmpty(title) ? " title=\"" + title + "\"" : "") + " src='" + ImageUtils.getUrl() + list.getLast() + "'/>");
		else if (size == ImageUtils.SIZE_LARGE && type != ImageUtils.INDEX_SPORT_CHAMPIONSHIP && type != ImageUtils.INDEX_SPORT_EVENT)
			html.append("<img alt='' src='/img/noimage.png?0'/>");
		return html.toString();
	}
	
	public static String writeURL(String main, String params, String text) {
		if (params != null)
			params = params.replaceAll("\\,\\s", "-").replaceAll("[\\[\\]]", "").replaceAll("\\-\\_(en|fr)$", "");
		return main + (StringUtils.notEmpty(text) ? "/" + StringUtils.urlEscape(text.replaceAll("\\&nbsp;\\-\\&nbsp\\;", "/")) : "") + (StringUtils.notEmpty(params) ? "/" + StringUtils.encode(params) : "");
	}

	public static String writeLink(String alias, int id, String text1, String text2) {
		StringBuffer html = new StringBuffer();
		StringBuffer url = new StringBuffer();
		text2 = (text2 != null ? text2 : text1);
		url.append("/" + ResourceUtils.getText("entity." + alias + ".1", ResourceUtils.LGDEFAULT).replaceAll("\\s", "").toLowerCase());
		url.append("/" + StringUtils.urlEscape(text2));
		url.append("/" + StringUtils.encode(alias + "-" + id + (alias.equals(Result.alias) ? "-1" : "")));
		if (text1 != null) {
			html.append("<a href='").append(url).append("'");
			if (alias.equals(Athlete.alias) && StringUtils.notEmpty(text2) && !text1.toLowerCase().equals(text2.toLowerCase()))
				html.append(" title=\"" + text2.replaceAll("\\\"", "'") + "\"");
			html.append(">" + (!text1.startsWith("<") ? text1.replaceAll("\\s", "&nbsp;")/*.replaceAll("\\-", "&#8209;")*/ : text1) + "</a>");
		}
		else
			html.append(ConfigUtils.getProperty("url") + url.toString().substring(1));
		return html.toString();
	}
	
	public static String writeDateLink(Object value, String text) throws Exception {
		StringBuffer html = new StringBuffer();
		StringBuffer url = new StringBuffer("/calendar");
		String s1 = "";
		String s2 = "";
		if (value != null) {
			if (value instanceof String) {
				SimpleDateFormat df = new SimpleDateFormat("dd/MM/yyyy");
				value = new Timestamp(df.parse(String.valueOf(value)).getTime());
			}
			if (value instanceof Timestamp) {
				s1 = StringUtils.toTextDate((Timestamp) value, ResourceUtils.LGDEFAULT, "yyyy-MM-dd");
				s2 = StringUtils.toTextDate((Timestamp) value, ResourceUtils.LGDEFAULT, "yyyyMMdd");
			}
		}
		url.append("/" + s1).append("/" + StringUtils.encode(s2));
		html.append("<a href='").append(url).append("'>").append(text).append("</a>");
		return html.toString();
	}

	public static String writeImgTable(String img, String text) {
		StringBuffer html = new StringBuffer();
		if (StringUtils.notEmpty(img)) {
			html.append("<table><tr><th>" + img + "</th>");
			html.append("<td>" + text + "</td></tr></table>");
		}
		else
			html.append(text);
		return html.toString();
	}

	public static String writeToggleTitle(String s, boolean collapsed) {
		StringBuffer html = new StringBuffer();
		html.append("<img alt='' src='" + ImageUtils.getRenderUrl() + (collapsed ? "expand" : "collapse") + ".gif' class='toggleimg' onclick='toggleContent(this)'/>");
		html.append("<span class='toggletext' onclick='toggleContent(this)'>" + s + "</span>");
		return html.toString();
	}

	public static StringBuffer writeHeader(Map<String, String> h, Integer sp, Contributor m, String lang) {
		StringBuffer html = new StringBuffer();
		html.append("<span class='title'>" + h.get("title") + "</span>");
		html.append("<span class='desc'>" + h.get("desc") + "</span>");
		String url = null;
		if (h.containsKey("url") && StringUtils.notEmpty(h.get("url"))) {
			url = h.get("url").substring(1);
			html.append("<span class='url'>" + ConfigUtils.getProperty("url") + url + "</span>");
		}
		html.append("<span class='infostats'>" + h.get("info") + "</span>");
		html.append("<div class='header'><table><tr>");
		html.append(h.containsKey("item0") ? "<td style='font-weight:bold;'>" + h.get("item0") + "</td>" : "");
		html.append(h.containsKey("item1") ? "<td class='arrow'>&nbsp;</td><td>" + h.get("item1") + "</td>" : "");
		html.append(h.containsKey("item2") ? "<td class='arrow'>&nbsp;</td><td>" + h.get("item2") + "</td>" : "");
		html.append(h.containsKey("item3") ? "<td class='arrow'>&nbsp;</td><td>" + h.get("item3") + "</td>" : "");
		html.append(h.containsKey("item4") ? "<td class='arrow'>&nbsp;</td><td>" + h.get("item4") + "</td>" : "");
		html.append(h.containsKey("item5") ? "<td class='arrow'>&nbsp;</td><td>" + h.get("item5") + "</td>" : "");
		html.append("<td style='padding-left:10px;'><img id='favimg' src='/img/menu/favorites2.png' style='cursor:pointer;'/></td>");
		html.append("</tr></table>");
		html.append("</div>");
		html.append("<div class='toolbar'>");
		html.append("<table><tr>");
		final String SHARE_OPTIONS = "<div id='shareopt' class='baroptions' style='display:none;'><table><tr><td onclick='share(\"fb\");' class='fb'>Facebook</td></tr><tr><td onclick='share(\"tw\");' class='tw'>Twitter</td></tr><tr><td onclick='share(\"gp\");' class='gp'>Google+</td></tr><tr><td onclick='share(\"bg\");' class='bg'>Blogger</td></tr><tr><td onclick='share(\"tm\");' class='tm'>Tumblr</td></tr></table><div><a href='javascript:$(\"shareopt\").hide();'>" + ResourceUtils.getText("cancel", lang) + "</a></div></div>";
		final String EXPORT_OPTIONS = "<div id='exportopt' class='baroptions' style='display:none;'><table><tr><td onclick='exportPage(\"html\");' class='html'>" + ResourceUtils.getText("web.page", lang) + "</td></tr><tr><td onclick='exportPage(\"csv\");' class='csv'>" + ResourceUtils.getText("csv.file", lang) + "</td></tr><tr><td onclick='exportPage(\"xls\");' class='excel'>" + ResourceUtils.getText("excel.sheet", lang) + "</td></tr><tr><td onclick='exportPage(\"pdf\");' class='pdf'>" + ResourceUtils.getText("pdf.file", lang) + "</td></tr><tr><td onclick='exportPage(\"txt\");' class='text'>" + ResourceUtils.getText("plain.text", lang) + "</td></tr></table><div><a href='javascript:$(\"exportopt\").hide();'>" + ResourceUtils.getText("cancel", lang) + "</a></div></div>";
		if (h.containsKey("errors"))
			html.append("<td>" + h.get("errors") + "</td>");
		if (m != null && url != null && sp != null && m.isSport(sp)) {
			if (url.matches("^results.*"))
				html.append("<td><input id='add' type='button' class='button add' onclick='location.href=\"" + h.get("url").replaceAll("\\/results", "/update") + "\";' value='" + ResourceUtils.getText("button.add", lang) + "'/></td>");	
			else if (url.matches("^result.*"))
				html.append("<td><input id='modify' type='button' class='button modify' onclick='location.href=\"" + h.get("url").replaceAll("\\/result", "/update") + "\";' value='" + ResourceUtils.getText("button.modify", lang) + "'/></td>");
		}
		html.append("<td><input id='share' type='button' class='button share' onclick='displayShare();' value='" + ResourceUtils.getText("share", lang) + "'/>" + SHARE_OPTIONS + "</td>");
		html.append("<td><input id='export' type='button' class='button export' onclick='displayExport();' value='" + ResourceUtils.getText("button.export", lang) + "'/>" + EXPORT_OPTIONS + "</td>");
		html.append("<td><input id='link' type='button' class='button link' onclick='displayLink();' value='" + ResourceUtils.getText("button.link", lang) + "'/></td>");
		html.append("<td><input id='print' type='button' class='button print' onclick='javascript:printCurrentTab();' value='" + ResourceUtils.getText("button.print", lang) + "'/></td>");
		html.append("<td><input id='info2' type='button' class='button info2' onclick='displayInfo();' value='" + ResourceUtils.getText("button.info", lang) + "'/></td>");
		html.append("</tr></table></div>");
		return html;
	}
	
	public static StringBuffer writeInfoHeader(LinkedHashMap<String, String> h, String lang) {
		StringBuffer html = new StringBuffer();
		String title = h.get("title");
		Integer width = (h.containsKey("width") ? Integer.valueOf(h.get("width")) : 0);
		html.append("<span class='title'>" + title.replaceAll(".{6}\\[.+#.*\\]$", "") + "</span>");
		html.append("<span class='url'>" + h.get("url") + "</span>");
		html.append("<span class='infostats'>" + h.get("info") + "</span>");
		// Info
		html.append("<ul class='uinfo'><li>");
		html.append("<table class='info'" + (width != null && width > 0 ? " style='width:" + width + "px;'" : "") + ">");
		if (h.containsKey("titlename"))
			html.append("<tr><th>" + h.get("titlename") + "</th></tr>");
		for (String key : h.keySet()) {
			if (!key.matches("(tab|^)title|titleEN|imgurl|source|url|info|\\_sport\\_|width|titlename") && StringUtils.notEmpty(h.get(key))) {
				html.append("<tr>" + (h.containsKey("_sport_") ? "" : "<th class='caption'>" + ResourceUtils.getText(key, lang) + "</th>"));
				html.append("<td" + (key.matches("logo|logosport|otherlogos|flag|otherflags|record|extlinks") ? " class='" + key + "'" : "") + ">" + h.get(key) + "</td></tr>");
			}
		}
		html.append("</table></li>");
		// Photo
		if (h.containsKey("imgurl"))
			html.append(ImageUtils.getPhotoFieldset(h.get("imgurl"), h.get("source"), lang));
		return html.append("</ul>");
	}

	public static String writeTip(String t, Object o) {
		StringBuffer html = new StringBuffer();
		long time = System.currentTimeMillis();
		html.append("<a style='cursor:help;' href='#" + t + "-" + time + "'><img src='" + ImageUtils.getRenderUrl() + "note.png'/></a>" + (o instanceof Collection ? "&nbsp;" + ((Collection)o).size() : ""));
		html.append("<div id='" + t + "-" + time + "' class='rendertip' style='display:none;'>" + (o instanceof String ? o : StringUtils.implode((Collection<String>) o, "<br/>")) + "</div>");
		return html.toString();
	}
	
	public static String writeComment(Integer id, String s) {
		StringBuffer html = new StringBuffer();
		if (StringUtils.notEmpty(s)) {
			s = s.replaceAll("\r|\n", "<br/>");
			html.append(s.matches("^\\#\\#.*") ? s.substring(2).replaceAll("\\s", "&nbsp;") : writeTip("cmt-" + id, s));
		}
		return html.toString();
	}

	public static String writeRecordItems(Collection<RefItem> cRecord, String lang) {
		StringBuffer sbRecord = new StringBuffer();
		String currentHeader = null;
		for (RefItem item : cRecord) {
			if (currentHeader == null || !currentHeader.equals(item.getTxt1() + item.getTxt2() + item.getTxt3())) {
				if (currentHeader != null)
					sbRecord.append("</table>");
				sbRecord.append("<table" + (sbRecord.toString().length() > 0 ? " style='margin-top:5px;'" : "") + "><tr><td style='border:none;'/>");
				if (StringUtils.notEmpty(item.getTxt1()))
					sbRecord.append("<th>" + (item.getTxt1().equalsIgnoreCase("#GOLD#") ? ImageUtils.getGoldMedImg(lang) : ResourceUtils.getText(item.getTxt1(), lang)) + "</th>");
				if (StringUtils.notEmpty(item.getTxt2()))
					sbRecord.append("<th>" + (item.getTxt2().equalsIgnoreCase("#SILVER#") ? ImageUtils.getSilverMedImg(lang) : ResourceUtils.getText(item.getTxt2(), lang)) + "</th>");
				if (StringUtils.notEmpty(item.getTxt3()))
					sbRecord.append("<th>" + (item.getTxt3().equalsIgnoreCase("#BRONZE#") ? ImageUtils.getBronzeMedImg(lang) : ResourceUtils.getText(item.getTxt3(), lang)) + "</th>");
				if (StringUtils.notEmpty(item.getTxt4()))
					sbRecord.append("<th>" + item.getTxt4() + "</th>");
				sbRecord.append("</tr>");
				currentHeader = item.getTxt1() + item.getTxt2() + item.getTxt3();
			}
			sbRecord.append("<tr><td style='text-align:right;padding-left:10px;font-weight:normal;text-decoration:underline;'>" + ResourceUtils.getText("rec." + item.getLabel(), lang).replaceAll("\\s", "&nbsp;") + "</td>");
			if (StringUtils.notEmpty(item.getTxt1()))
				sbRecord.append("<td>" + item.getCount1() + "</td>");
			if (StringUtils.notEmpty(item.getTxt2()))
				sbRecord.append("<td>" + item.getCount2() + "</td>");
			if (StringUtils.notEmpty(item.getTxt3()))	
				sbRecord.append("<td>" + item.getCount3() + "</td>");
			if (StringUtils.notEmpty(item.getTxt4()))
				sbRecord.append("<td>" + item.getCount4() + "</td>");
			sbRecord.append("</tr>");
		}
		if (sbRecord.toString().length() > 0)
			sbRecord.append("</table>");
		return sbRecord.toString();
	}
	
	public static String writeExternalLinks(String alias, Object id, String lang) throws Exception {
		StringBuffer sbHtml = new StringBuffer();
		String currentType = null;
		List<ExternalLink> list = DatabaseHelper.execute("from ExternalLink where entity='" + alias + "' and idItem=" + id + " order by id");
		for (ExternalLink link : list) {
			// Title
			if (currentType == null || !currentType.equalsIgnoreCase(link.getType())) {
				if (link.getType().equals("wiki"))
					sbHtml.append("<tr><th>" + ResourceUtils.getText("wikipedia", lang) + "</th></tr>");
				else if (link.getType().matches(".*\\-ref$")) {
					HashMap<String, String> h = new HashMap<String, String>();
					h.put("oly-ref", "Olympics");
					h.put("bkt-ref", "Basketball");
					h.put("bb-ref", "Baseball");
					h.put("ft-ref", "Pro-football");
					h.put("hk-ref", "Hockey");
					sbHtml.append("<tr><th>" + h.get(link.getType()) + "-reference</th></tr><tr>");
				}
				else
					sbHtml.append("<tr><th>" + ResourceUtils.getText("extlink." + link.getType(), lang).replaceAll("\\s", "&nbsp;") + "</th></tr>");
			}
			currentType = link.getType();
			// Link
			if (link.getType().equals("wiki"))
				sbHtml.append("<tr><td><table><tr><td style='width:16px;'><img alt='Wiki' src='/img/render/link-wiki.png'/></td><td>&nbsp;<a href='" + link.getUrl() + "' target='_blank'>" + link.getUrl() + "</a></td></tr></table></td></tr>");
			else if (link.getType().matches(".*\\-ref$"))
				sbHtml.append("<td><table><tr><td style='width:16px;'><img alt='spref' src='/img/render/link-" + link.getType().replaceAll("\\-ref", "") + "ref.png'/></td><td>&nbsp;<a href='" + link.getUrl() + "' target='_blank'>" + link.getUrl() + "</a></td></tr></table></td></tr>");
			else
				sbHtml.append("<tr><td><table><tr><td style='width:16px;'><img alt='spref' src='/img/render/website.png'/></td><td>&nbsp;<a href='" + link.getUrl() + "' target='_blank'>" + link.getUrl() + "</a></td></tr></table></td></tr>");
		}
		return (sbHtml.toString().length() > 0 ? "<table>" + sbHtml.append("</table>").toString() : "");
	}
	
	public static void setHeadInfo(HttpServletRequest req, String header) throws Exception {
		Document d = Jsoup.parse(header);
		Elements e = d.getElementsByTag("span");
		String title = e.get(0).text();
		String desc = e.get(1).text();
		req.setAttribute("title", StringUtils.getTitle(title));
		req.setAttribute("desc", desc);
	}
	
}