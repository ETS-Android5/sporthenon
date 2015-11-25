package com.sporthenon.web.servlet;

import java.io.IOException;
import java.lang.reflect.Method;
import java.math.BigInteger;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.log4j.Logger;
import org.dom4j.Document;
import org.dom4j.DocumentFactory;
import org.dom4j.Element;
import org.dom4j.io.OutputFormat;
import org.dom4j.io.XMLWriter;
import org.jsoup.Jsoup;
import org.jsoup.select.Elements;

import com.sporthenon.db.DatabaseHelper;
import com.sporthenon.db.PicklistBean;
import com.sporthenon.db.entity.Championship;
import com.sporthenon.db.entity.City;
import com.sporthenon.db.entity.Complex;
import com.sporthenon.db.entity.Event;
import com.sporthenon.db.entity.Result;
import com.sporthenon.db.entity.Sport;
import com.sporthenon.db.entity.meta.InactiveItem;
import com.sporthenon.db.entity.meta.RefItem;
import com.sporthenon.db.function.ResultsBean;
import com.sporthenon.utils.HtmlUtils;
import com.sporthenon.utils.ImageUtils;
import com.sporthenon.utils.StringUtils;
import com.sporthenon.utils.res.ResourceUtils;
import com.sporthenon.web.HtmlConverter;

public class AndroidServlet extends AbstractServlet {

	private static final long serialVersionUID = 1L;

	public AndroidServlet() {
	}

	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		doPost(request, response);
	}

	protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		try {
			HashMap<String, Object> hParams = ServletHelper.getParams(request);
			String lang = (hParams.containsKey("lang") ? String.valueOf(hParams.get("lang")) : ResourceUtils.LGDEFAULT);
			String label = "label" + (lang != null && !lang.equalsIgnoreCase(ResourceUtils.LGDEFAULT) ? lang.toUpperCase() : "");
			String p = String.valueOf(hParams.get("p"));
			String p2 = String.valueOf(hParams.get("p2"));

	        //Inactive Events
			List<String> lInactive = new ArrayList<String>();
			if (p2.matches("(?i:" + Event.alias + "|SE|SE2)")) {
				String[] t = p.split("\\-");
				for (InactiveItem item : (List<InactiveItem>) DatabaseHelper.execute("from InactiveItem where idSport=" + t[0]))
					lInactive.add(item.getIdChampionship() + "-" + item.getIdEvent() + (item.getIdSubevent() != null ? "-" + item.getIdSubevent() : "") + (item.getIdSubevent2() != null ? "-" + item.getIdSubevent2() : ""));
			}
			
	        Document doc = DocumentFactory.getInstance().createDocument();
	        Element root = doc.addElement("picklist");
	        root.addAttribute("id", p2);
	        if (p2.equalsIgnoreCase(Sport.alias))
	        	addItems(doc, root, ImageUtils.INDEX_SPORT, DatabaseHelper.getEntityPicklist(Sport.class, "label", null, lang), null, null, null, null);
	        else if (p2.equalsIgnoreCase(Championship.alias)) {
	        	String filter = "sport.id=" + p;
	        	addItems(doc, root, ImageUtils.INDEX_SPORT_CHAMPIONSHIP, DatabaseHelper.getPicklist(Result.class, "championship", filter, null, "x.championship.index, x.championship." + label, lang), null, p, null, null);
	        }
	        else if (p2.equalsIgnoreCase(Event.alias)) {
	        	String[] t = p.split("\\-");
	        	String filter = "sport.id=" + t[0] + " and championship.id=" + t[1];
	        	addItems(doc, root, ImageUtils.INDEX_SPORT_EVENT, DatabaseHelper.getPicklist(Result.class, "event", filter, null, "x.event.index, x.event." + label, lang), lInactive, t[0], t[1], "SELECT COUNT(DISTINCT id_subevent) from \"Result\" WHERE id_sport=" + t[0] + " and id_championship=" + t[1] + " and id_event=#ID#");
	        }
	        else if (p2.equalsIgnoreCase("SE")) {
	        	String[] t = p.split("\\-");
	        	String filter = "sport.id=" + t[0] + " and championship.id=" + t[1] + " and event.id=" + t[2];
	        	addItems(doc, root, ImageUtils.INDEX_SPORT_EVENT, DatabaseHelper.getPicklist(Result.class, "subevent", filter, null, "x.subevent.index, x.subevent." + label, lang), lInactive, t[0], t[1] + "-" + t[2], "SELECT COUNT(DISTINCT id_subevent2) from \"Result\" WHERE id_sport=" + t[0] + " and id_championship=" + t[1] + " and id_event=" + t[2] + " and id_subevent=#ID#");
	        }
	        else if (p2.equalsIgnoreCase("SE2")) {
	        	String[] t = p.split("\\-");
	        	String filter = "sport.id=" + t[0] + " and championship.id=" + t[1] + " and event.id=" + t[2] + " and subevent.id=" + t[3];
	        	addItems(doc, root, ImageUtils.INDEX_SPORT_EVENT, DatabaseHelper.getPicklist(Result.class, "subevent2", filter, null, "x.subevent2.index, x.subevent2." + label, lang), lInactive, t[0], t[1] + "-" + t[2] + "-" + t[3], null);
	        }
	        else if (p2.equalsIgnoreCase(Result.alias)) {
	        	String[] t = p.split("\\-");
	        	Integer sp = new Integer(t[0]);
	        	Integer cp = new Integer(t[1]);
	        	Integer ev = new Integer(t[2]);
	        	Integer se = new Integer(t.length > 3 ? t[3] : "0");
	        	Integer se2 = new Integer(t.length > 4 ? t[4] : "0");
	        	
	        	ArrayList<Object> lFuncParams = new ArrayList<Object>();
				lFuncParams.add(sp);
				lFuncParams.add(cp);
				lFuncParams.add(ev);
				lFuncParams.add(se);
				lFuncParams.add(se2);
				lFuncParams.add("0");
				lFuncParams.add("_" + lang);
				Event ev_ = (Event) DatabaseHelper.loadEntity(Event.class, (se2 > 0 ? se2 : (se > 0 ? se : ev)));
				addResultItems(doc, root, ev_, DatabaseHelper.call("GetResults", lFuncParams), lang);
	        }
	        else if (p2.equalsIgnoreCase("R1")) {
	        	final int MAX_RANKS = 20;
	        	Result r = (Result) DatabaseHelper.loadEntity(Result.class, p);
	        	Element sp = root.addElement("sport");
	        	sp.addAttribute("id", String.valueOf(r.getSport().getId()));
	        	sp.addAttribute("img", getImage(ImageUtils.INDEX_SPORT, r.getSport().getId(), ImageUtils.SIZE_LARGE, null, null));
	        	sp.addText(r.getSport().getLabel(lang));
	        	Element cp = root.addElement("championship");
	        	cp.addAttribute("id", String.valueOf(r.getChampionship().getId()));
	        	cp.addAttribute("img", getImage(ImageUtils.INDEX_SPORT_CHAMPIONSHIP, r.getSport().getId() + "-" + r.getChampionship().getId(), ImageUtils.SIZE_LARGE, null, null));
	        	cp.addText(r.getChampionship().getLabel(lang));
	        	Element ev = root.addElement("event");
	        	ev.addAttribute("id", String.valueOf(r.getEvent().getId()));
	        	ev.addAttribute("img", getImage(ImageUtils.INDEX_SPORT_EVENT, r.getSport().getId() + "-" + r.getEvent().getId(), ImageUtils.SIZE_LARGE, null, null));
	        	ev.addText(r.getEvent().getLabel(lang));
	        	if (r.getSubevent() != null) {
	        		Element se = root.addElement("subevent");
	        		se.addAttribute("id", String.valueOf(r.getSubevent().getId()));
		        	se.addAttribute("img", getImage(ImageUtils.INDEX_SPORT_EVENT, r.getSport().getId() + "-" + r.getSubevent().getId(), ImageUtils.SIZE_LARGE, null, null));
		        	se.addText(r.getSubevent().getLabel(lang));
	        	}
	        	if (r.getSubevent2() != null) {
	        		Element se2 = root.addElement("subevent2");
	        		se2.addAttribute("id", String.valueOf(r.getSubevent2().getId()));
		        	se2.addAttribute("img", getImage(ImageUtils.INDEX_SPORT_EVENT, r.getSport().getId() + "-" + r.getSubevent2().getId(), ImageUtils.SIZE_LARGE, null, null));
		        	se2.addText(r.getSubevent2().getLabel(lang));
	        	}
	        	if (StringUtils.notEmpty(r.getDate2())) {
	        		Element dates = root.addElement("dates");
	        		if (StringUtils.notEmpty(r.getDate1()))
	        			dates.addAttribute("date1", StringUtils.toTextDate(r.getDate1(), lang, "d MMMM yyyy"));
	        		dates.addAttribute("date2", StringUtils.toTextDate(r.getDate2(), lang, "d MMMM yyyy"));
	        	}
				if (StringUtils.notEmpty(r.getComplex2()) || StringUtils.notEmpty(r.getCity2())) {
					String pl1 = null;
					String pl2 = null;
					Integer cn1 = null;
					Integer cn2 = null;
					if (r.getComplex1() != null) {
						Complex cx = r.getComplex1();
						pl1 = HtmlConverter.getPlace(cx.getId(), cx.getCity().getId(), cx.getCity().getState() != null ? cx.getCity().getState().getId() : null, cx.getCity().getCountry().getId(), cx.getLabel(lang), cx.getCity().getLabel(lang), cx.getCity().getState() != null ? cx.getCity().getState().getLabel(lang) : null, cx.getCity().getCountry().getLabel(lang), cx.getLabel(), cx.getCity().getLabel(), cx.getCity().getState() != null ? cx.getCity().getState().getLabel() : null, cx.getCity().getCountry().getLabel(), r.getYear().getLabel());
						cn1 = cx.getCity().getCountry().getId();
					}
					else if (r.getCity1() != null) {
						City ct = r.getCity1();
						pl1 = HtmlConverter.getPlace(null, ct.getId(), ct.getState() != null ? ct.getState().getId() : null, ct.getCountry().getId(), null, ct.getLabel(lang), ct.getState() != null ? ct.getState().getLabel(lang) : null, ct.getCountry().getLabel(lang), null, ct.getLabel(), ct.getState() != null ? ct.getState().getLabel() : null, ct.getCountry().getLabel(), r.getYear().getLabel());
						cn1 = ct.getCountry().getId();
					}
					if (r.getComplex2() != null) {
						Complex cx = r.getComplex2();
						pl2 = HtmlConverter.getPlace(cx.getId(), cx.getCity().getId(), cx.getCity().getState() != null ? cx.getCity().getState().getId() : null, cx.getCity().getCountry().getId(), cx.getLabel(lang), cx.getCity().getLabel(lang), cx.getCity().getState() != null ? cx.getCity().getState().getLabel(lang) : null, cx.getCity().getCountry().getLabel(lang), cx.getLabel(), cx.getCity().getLabel(), cx.getCity().getState() != null ? cx.getCity().getState().getLabel() : null, cx.getCity().getCountry().getLabel(), r.getYear().getLabel());
						cn2 = cx.getCity().getCountry().getId();
					}
					else if (r.getCity2() != null) {
						City ct = r.getCity2();
						pl2 = HtmlConverter.getPlace(null, ct.getId(), ct.getState() != null ? ct.getState().getId() : null, ct.getCountry().getId(), null, ct.getLabel(lang), ct.getState() != null ? ct.getState().getLabel(lang) : null, ct.getCountry().getLabel(lang), null, ct.getLabel(), ct.getState() != null ? ct.getState().getLabel() : null, ct.getCountry().getLabel(), r.getYear().getLabel());
						cn2 = ct.getCountry().getId();
					}
					if (StringUtils.notEmpty(pl1)) {
						Element place1 = root.addElement("place1");
						if (cn1 != null) {
							place1.addAttribute("id", String.valueOf(cn1));
							place1.addAttribute("img", getImage(ImageUtils.INDEX_COUNTRY, cn1, ImageUtils.SIZE_SMALL, r.getYear().getLabel(), null));	
						}
						place1.addText(StringUtils.removeTags(pl1));
					}
					Element place2 = root.addElement("place2");
					if (cn2 != null) {
						place2.addAttribute("id", String.valueOf(cn2));
						place2.addAttribute("img", getImage(ImageUtils.INDEX_COUNTRY, cn2, ImageUtils.SIZE_SMALL, r.getYear().getLabel(), null));	
					}
					place2.addText(StringUtils.removeTags(pl2));
				}
			
				// Result
				ArrayList<Object> lFuncParams = new ArrayList<Object>();
				lFuncParams.add(r.getSport().getId());
				lFuncParams.add(r.getChampionship().getId());
				lFuncParams.add(r.getEvent().getId());
				lFuncParams.add(r.getSubevent() != null ? r.getSubevent().getId() : 0);
				lFuncParams.add(r.getSubevent2() != null ? r.getSubevent2().getId() : 0);
				lFuncParams.add(String.valueOf(r.getYear().getId()));
				lFuncParams.add("_" + lang);
				List<ResultsBean> list = (List<ResultsBean>) DatabaseHelper.call("GetResults", lFuncParams);
				if (list != null && !list.isEmpty()) {
					ResultsBean bean = list.get(0);
					String[] tEntity = new String[MAX_RANKS];
					String[] tEntityRel = new String[MAX_RANKS];
					String[] tEntityImg = new String[MAX_RANKS];
					String[] tResult = new String[MAX_RANKS];
					Event ev_ = (Event) DatabaseHelper.loadEntity(Event.class, (r.getSubevent2() != null ? r.getSubevent2().getId() : (r.getSubevent() != null ? r.getSubevent().getId() : r.getEvent().getId())));
					int type_ = ev_.getType().getNumber();
					if (bean.getRsRank1() != null) {
						tEntity[0] = HtmlConverter.getResultsEntity(type_, bean.getRsRank1(), bean.getEn1Str1(), bean.getEn1Str2(), bean.getEn1Str3(), bean.getEn1Rel2Code(), bean.getYrLabel(), null);
						tEntityRel[0] = HtmlConverter.getResultsEntityRel(bean.getEn1Rel1Id(), bean.getEn1Rel1Label(), bean.getEn1Rel1Label(), bean.getEn1Rel2Id(), bean.getEn1Rel2Label(), bean.getEn1Rel2Label(), bean.getEn1Rel2LabelEN(), false, false, bean.getYrLabel());
						tResult[0] = bean.getRsResult1();
					}
					if (bean.getRsRank2() != null) {
						tEntity[1] = HtmlConverter.getResultsEntity(type_, bean.getRsRank2(), bean.getEn2Str1(), bean.getEn2Str2(), bean.getEn2Str3(), bean.getEn2Rel2Code(), bean.getYrLabel(), null);
						tEntityRel[1] = HtmlConverter.getResultsEntityRel(bean.getEn2Rel1Id(), bean.getEn2Rel1Label(), bean.getEn2Rel1Label(), bean.getEn2Rel2Id(), bean.getEn2Rel2Label(), bean.getEn2Rel2Label(), bean.getEn2Rel2LabelEN(), false, false, bean.getYrLabel());
						tResult[1] = bean.getRsResult2();
					}
					if (bean.getRsRank3() != null) {
						tEntity[2] = HtmlConverter.getResultsEntity(type_, bean.getRsRank3(), bean.getEn3Str1(), bean.getEn3Str2(), bean.getEn3Str3(), bean.getEn3Rel2Code(), bean.getYrLabel(), null);
						tEntityRel[2] = HtmlConverter.getResultsEntityRel(bean.getEn3Rel1Id(), bean.getEn3Rel1Label(), bean.getEn3Rel1Label(), bean.getEn3Rel2Id(), bean.getEn3Rel2Label(), bean.getEn3Rel2Label(), bean.getEn3Rel2LabelEN(), false, false, bean.getYrLabel());
						tResult[2] = bean.getRsResult3();
					}
					if (bean.getRsRank4() != null) {
						tEntity[3] = HtmlConverter.getResultsEntity(type_, bean.getRsRank4(), bean.getEn4Str1(), bean.getEn4Str2(), bean.getEn4Str3(), bean.getEn4Rel2Code(), bean.getYrLabel(), null);
						tEntityRel[3] = HtmlConverter.getResultsEntityRel(bean.getEn3Rel1Id(), bean.getEn4Rel1Label(), bean.getEn4Rel1Label(), bean.getEn4Rel2Id(), bean.getEn4Rel2Label(), bean.getEn4Rel2Label(), bean.getEn4Rel2LabelEN(), false, false, bean.getYrLabel());
						tResult[3] = bean.getRsResult4();
					}
					if (bean.getRsRank5() != null) {
						tEntity[4] = HtmlConverter.getResultsEntity(type_, bean.getRsRank5(), bean.getEn5Str1(), bean.getEn5Str2(), bean.getEn5Str3(), bean.getEn5Rel2Code(), bean.getYrLabel(), null);
						tEntityRel[4] = HtmlConverter.getResultsEntityRel(bean.getEn5Rel1Id(), bean.getEn5Rel1Label(), bean.getEn5Rel1Label(), bean.getEn5Rel2Id(), bean.getEn5Rel2Label(), bean.getEn5Rel2Label(), bean.getEn5Rel2LabelEN(), false, false, bean.getYrLabel());
						tResult[4] = bean.getRsResult5();
					}
					if (bean.getRsRank6() != null) {
						tEntity[5] = HtmlConverter.getResultsEntity(type_, bean.getRsRank6(), bean.getEn6Str1(), bean.getEn6Str2(), bean.getEn6Str3(), bean.getEn6Rel2Code(), bean.getYrLabel(), null);
						tEntityRel[5] = HtmlConverter.getResultsEntityRel(bean.getEn6Rel1Id(), bean.getEn6Rel1Label(), bean.getEn6Rel1Label(), bean.getEn6Rel2Id(), bean.getEn6Rel2Label(), bean.getEn6Rel2Label(), bean.getEn6Rel2LabelEN(), false, false, bean.getYrLabel());
					}
					if (bean.getRsRank7() != null) {
						tEntity[6] = HtmlConverter.getResultsEntity(type_, bean.getRsRank7(), bean.getEn7Str1(), bean.getEn7Str2(), bean.getEn7Str3(), bean.getEn7Rel2Code(), bean.getYrLabel(), null);
						tEntityRel[6] = HtmlConverter.getResultsEntityRel(bean.getEn7Rel1Id(), bean.getEn7Rel1Label(), bean.getEn7Rel1Label(), bean.getEn7Rel2Id(), bean.getEn7Rel2Label(), bean.getEn7Rel2Label(), bean.getEn7Rel2LabelEN(), false, false, bean.getYrLabel());
					}
					if (bean.getRsRank8() != null) {
						tEntity[7] = HtmlConverter.getResultsEntity(type_, bean.getRsRank8(), bean.getEn8Str1(), bean.getEn8Str2(), bean.getEn8Str3(), bean.getEn8Rel2Code(), bean.getYrLabel(), null);
						tEntityRel[7] = HtmlConverter.getResultsEntityRel(bean.getEn8Rel1Id(), bean.getEn8Rel1Label(), bean.getEn8Rel1Label(), bean.getEn8Rel2Id(), bean.getEn8Rel2Label(), bean.getEn8Rel2Label(), bean.getEn8Rel2LabelEN(), false, false, bean.getYrLabel());
					}
					if (bean.getRsRank9() != null) {
						tEntity[8] = HtmlConverter.getResultsEntity(type_, bean.getRsRank9(), bean.getEn9Str1(), bean.getEn9Str2(), bean.getEn9Str3(), bean.getEn9Rel2Code(), bean.getYrLabel(), null);
						tEntityRel[8] = HtmlConverter.getResultsEntityRel(bean.getEn9Rel1Id(), bean.getEn9Rel1Label(), bean.getEn9Rel1Label(), bean.getEn9Rel2Id(), bean.getEn9Rel2Label(), bean.getEn9Rel2Label(), bean.getEn9Rel2LabelEN(), false, false, bean.getYrLabel());
					}
					boolean isDouble = (type_ == 4 || (bean.getRsComment() != null && bean.getRsComment().equals("#DOUBLE#")));
					boolean isTriple = (type_ == 5 || (bean.getRsComment() != null && bean.getRsComment().equals("#TRIPLE#")));
					HtmlConverter.setTies(HtmlConverter.getTieList(isDouble, isTriple, bean.getRsExa()), type_, tEntity, tEntityRel);
					if (isTriple || isDouble) {
						tEntity = StringUtils.removeNulls(tEntity);
						tEntityRel = StringUtils.removeNulls(tEntityRel);
					}
					org.jsoup.nodes.Document d = null;
					for (int i = 0 ; i < MAX_RANKS ; i++) {
						if (StringUtils.notEmpty(tEntity[i])) {
							d = Jsoup.parse(tEntity[i]);
							StringBuffer sb = new StringBuffer();
							for (org.jsoup.nodes.Element e : d.getElementsByTag("a"))
								sb.append(sb.toString().length() > 0 ? "|" : "").append(e.text());
							tEntity[i] = sb.toString();
							Elements imgs = d.getElementsByTag("img");
							if (imgs != null && imgs.size() > 0)
								tEntityImg[i] = imgs.get(0).attr("src");
							
							if (StringUtils.notEmpty(tEntityRel[i])) {
								d = Jsoup.parse(tEntityRel[i]);
								if (tEntityImg[i] == null) {
									sb = new StringBuffer();
									for (org.jsoup.nodes.Element e : d.getElementsByTag("img"))
										sb.append(sb.toString().length() > 0 ? "|" : "").append(e.attr("src"));
									tEntityImg[i] = sb.toString();	
								}
								sb = new StringBuffer();
								for (org.jsoup.nodes.Element e : d.getElementsByTag("a"))
									sb.append(sb.toString().length() > 0 ? "|" : "").append(e.text());
								tEntityRel[i] = sb.toString();
							}
								
							Element rank = root.addElement("rank" + (i + 1));
							rank.addAttribute("img", tEntityImg[i]);
							rank.addAttribute("result", tResult[i]);
							rank.addAttribute("rel", tEntityRel[i]);
							rank.addText(tEntity[i]);
						}
					}
				}
	        }
	        
	        response.setContentType("text/xml");
	        response.setCharacterEncoding("utf-8");
	        XMLWriter writer = new XMLWriter(response.getOutputStream(), OutputFormat.createPrettyPrint());
	        writer.write(doc);
	        writer.flush();
	        response.flushBuffer();
		}
		catch (Exception e) {
			Logger.getLogger("sh").error(e.getMessage(), e);
		}
	}
	
	public static String getImage(short type, Object id, char size, String year, String title) {
		String html = HtmlUtils.writeImage(type, id, size, year, title);
		return html.replaceAll(".*\\ssrc\\=\\'|\\'\\/\\>", "");
	}
	
	private void addItems(Document doc, Element root, short index, Collection<PicklistBean> picklist, List<String> lInactive, Object spid, String currentPath, String subcountSQL) throws Exception {
		if (picklist != null && picklist.size() > 0) {
			for (PicklistBean plb : picklist) {
				Element item = root.addElement("item");
				String img = HtmlUtils.writeImage(index, (spid != null ? spid + "-" : "") + plb.getValue(), ImageUtils.SIZE_LARGE, null, null);
				int id = plb.getValue();
				String text = plb.getText();
				if (lInactive != null && lInactive.contains(currentPath + "-" + id))
					text = "+" + text;
				item.addAttribute("value", String.valueOf(id));
				item.addAttribute("text", text);
				item.addAttribute("img", img.replaceAll(".*src\\='|'\\/\\>", ""));
				Integer n = 1;
				if (subcountSQL != null)
					n = ((BigInteger) DatabaseHelper.executeNative(subcountSQL.replace("#ID#", String.valueOf(id))).get(0)).intValue();
				item.addAttribute("subcount", String.valueOf(n));
			}
		}
	}
	
	private void addResultItems(Document doc, Element root, Event ev, Collection<ResultsBean> list, String lang) {
		if (list != null && list.size() > 0) {
			List<String> lIds = new ArrayList<String>();
			Integer tp = ev.getType().getNumber();
			for (ResultsBean bean : list) {
				boolean isDouble = (tp == 4 || (bean.getRsComment() != null && bean.getRsComment().equals("#DOUBLE#")));
				boolean isTriple = (tp == 5 || (bean.getRsComment() != null && bean.getRsComment().equals("#TRIPLE#")));
				Element item = root.addElement("item");
				lIds.add(String.valueOf(bean.getRsId()));
				item.addAttribute("id", String.valueOf(bean.getRsId()));
				item.addAttribute("year", bean.getYrLabel());
				item.addAttribute("type", String.valueOf(tp));
				item.addAttribute("str1", bean.getEn1Str1()); item.addAttribute("str2", bean.getEn1Str2()); item.addAttribute("str3", bean.getEn1Str3());
				item.addAttribute("str4", bean.getEn2Str1()); item.addAttribute("str5", bean.getEn2Str2()); item.addAttribute("str6", bean.getEn2Str3());
				item.addAttribute("str7", bean.getEn3Str1()); item.addAttribute("str8", bean.getEn3Str2()); item.addAttribute("str9", bean.getEn3Str3());
				item.addAttribute("tie1", isDouble ? "1" : "0");
				item.addAttribute("tie2", isTriple ? "1" : "0");
				item.addAttribute("rs1", bean.getRsResult1()); item.addAttribute("rs2", bean.getRsResult2()); item.addAttribute("rs3", bean.getRsResult3());
				item.addAttribute("score", bean.getRsRank1() != null && bean.getRsRank2() != null && StringUtils.notEmpty(bean.getRsResult1()) && !StringUtils.notEmpty(bean.getRsResult2()) && !StringUtils.notEmpty(bean.getRsResult3()) && !StringUtils.notEmpty(bean.getRsResult4()) && !StringUtils.notEmpty(bean.getRsResult5()) ? "1" : "0");
				try {
					StringBuffer sbCode = new StringBuffer();
					StringBuffer sbImg = new StringBuffer();
					for (int i = 1 ; i <= 3 ; i++) {
						Method m = ResultsBean.class.getMethod("getRsRank" + i);
						Object o = m.invoke(bean);
						if (o != null) {
							Integer id = (Integer) o;
							String img = null;
							if (tp < 10) {
								Integer tm = StringUtils.toInt(ResultsBean.class.getMethod("getEn" + i + "Rel1Id").invoke(bean));
								Integer cn = StringUtils.toInt(ResultsBean.class.getMethod("getEn" + i + "Rel2Id").invoke(bean));
								if (tm != null && tm> 0)
									img = HtmlUtils.writeImage(ImageUtils.INDEX_TEAM, tm, ImageUtils.SIZE_SMALL, bean.getYrLabel(), null);
								else {
									img = HtmlUtils.writeImage(ImageUtils.INDEX_COUNTRY, cn, ImageUtils.SIZE_SMALL, bean.getYrLabel(), null);
									sbCode.append(sbCode.toString().length() > 0 ? "|" : "").append(ResultsBean.class.getMethod("getEn" + i + "Rel2Code").invoke(bean));
								}
							}
							else if (tp == 50)
								img = HtmlUtils.writeImage(ImageUtils.INDEX_TEAM, id, ImageUtils.SIZE_SMALL, bean.getYrLabel(), null);
							else if (tp == 99)
								img = HtmlUtils.writeImage(ImageUtils.INDEX_COUNTRY, id, ImageUtils.SIZE_SMALL, bean.getYrLabel(), null);
							sbImg.append(sbImg.toString().length() > 0 ? "|" : "").append(img.replaceAll(".*src\\='|'\\/\\>", ""));
							
						}
					}
					item.addAttribute("code", sbCode.toString());
					item.addAttribute("img", sbImg.toString());
				}
				catch (Exception e) {
					Logger.getLogger("sh").error(e.getMessage(), e);
				}
			}
			try {
				ArrayList<Object> lParams = new ArrayList<Object>();
				lParams.add(StringUtils.implode(lIds, ","));
				lParams.add("_" + lang);
				List<RefItem> list_ = (List<RefItem>) DatabaseHelper.call("WinRecords", lParams);
				if (list_ != null && list_.size() > 0) {
					RefItem item = list_.get(0);
					String str = item.getLabel();
					if (item.getIdRel1() < 10) {
						String[] t = str.split("\\,\\s", -1);
						str = StringUtils.toFullName(t[0], t[1], item.getLabelRel1(), true);
					}
					root.addAttribute("winrec-name", str);
					root.addAttribute("winrec-count", String.valueOf(item.getCount1()));
				}
			}
			catch (Exception e) {
				Logger.getLogger("sh").error(e.getMessage(), e);
			}
		}
	}

}